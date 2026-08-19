import 'package:flutter/foundation.dart';
import '../models/job_type_schema.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/job_type_schema_service.dart';

const _kBusinessSchemaTestToken =
    'eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiJvbmdvLWp3dCIsInN1YiI6ImFpZG91YmxlQGdvc3VyZS5haSIsImF1dGhvcml0aWVzIjpbXSwidGVuYW50IjoiYWlkb3VibGUiLCJvcmdJZCI6IjY5YzI4MDAzYjI2M2RkMDNiYzkyZDIxMCIsInJvbGVOYW1lIjoiU3ViIEFkbWluIiwidXNlcklkIjoiNjljMjgwMDNiMjYzZGQwM2JjOTJkMjE1IiwiaWF0IjoxNzg3MTE4MTI3LCJleHAiOjE3ODc3MjI5Mjd9.o8nNYbGimxOiuEQY8ZydlMhccMv-PxkVaz4s34WQZ1largaN5vCz0dFTkYs9s3DrNT79WUjVM42BUqlO8wDFaA';

class SignupViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final WorkspaceRepository _workspaceRepository;
  final ApiClient _apiClient;

  SignupViewModel(this._authRepository, this._workspaceRepository, this._apiClient) {
    _loadSchema();
  }

  int _step = 0;
  int get step => _step;

  JobTypeSchema? _schema;
  JobTypeSchema? get schema => _schema;

  bool _loadingSchema = false;
  bool get loadingSchema => _loadingSchema;

  bool _schemaFailed = false;
  bool get schemaFailed => _schemaFailed;

  final Map<String, dynamic> _values = {};
  dynamic valueOf(String fieldName) => _values[fieldName];

  final String _size = '';
  String get size => _size;

  String _region = 'in';
  String get region => _region;

  String _planId = 'growth';
  String get planId => _planId;

  bool _submitting = false;
  bool get submitting => _submitting;

  static const _kSkipTypes = {'SubJob'};

  List<String> get groupNames {
    final s = _schema;
    if (s == null) return const [];
    final seen = <String>[];
    for (final f in s.fields) {
      if (_kSkipTypes.contains(f.type) || f.groupName.isEmpty) continue;
      if (!seen.contains(f.groupName)) seen.add(f.groupName);
    }
    return seen;
  }

  List<JobTypeField> fieldsForGroup(String group) {
    final s = _schema;
    if (s == null) return const [];
    return s.fieldsInGroup(group).where((f) => !_kSkipTypes.contains(f.type)).toList();
  }

  int get totalSteps => groupNames.length + 1;

  String? _parentFieldNameOf(JobTypeField field) {
    final s = _schema;
    if (s == null) return null;
    for (final f in s.fields) {
      if (f.dependentFields == field.name) return f.name;
    }
    return null;
  }

  List<String> optionsForField(JobTypeField field) {
    final s = _schema;
    if (s == null) return const [];
    final parentName = _parentFieldNameOf(field);
    final parentValue = parentName == null ? null : _values[parentName] as String?;
    return s.optionsFor(field, parentSelectionLabel: parentValue);
  }

  void setTextValue(String fieldName, String value) {
    _values[fieldName] = value;
    notifyListeners();
  }

  void pickSingleValue(JobTypeField field, String value) {
    _values[field.name] = value;
    _clearDependents(field.name);
    notifyListeners();
  }

  void toggleMultiValue(JobTypeField field, String option) {
    final current = Set<String>.from((_values[field.name] as Set<String>?) ?? const <String>{});
    if (!current.remove(option)) current.add(option);
    _values[field.name] = current;
    notifyListeners();
  }

  void _clearDependents(String fieldName) {
    final s = _schema;
    if (s == null) return;
    for (final f in s.fields) {
      if (f.dependentFields == fieldName) _values.remove(f.name);
    }
  }

  Future<void> _loadSchema() async {
    _loadingSchema = true;
    _schemaFailed = false;
    notifyListeners();
    final result = await fetchJobTypeSchema(_apiClient, 'Business', bearerTokenOverride: _kBusinessSchemaTestToken);
    _schema = result;
    _schemaFailed = result == null;
    if (result != null && result.fieldNamed('Work Email') != null && _values['Work Email'] == null) {
      final email = _authRepository.currentUser?.username;
      if (email != null && email.isNotEmpty) _values['Work Email'] = email;
    }
    _loadingSchema = false;
    notifyListeners();
  }

  Future<void> retryLoadSchema() => _loadSchema();

  void pickRegion(String r) {
    _region = r;
    notifyListeners();
  }

  void pickPlan(String id) {
    _planId = id;
    notifyListeners();
  }

  String? _mandatoryErrorFor(JobTypeField field) {
    if (!field.mandatory) return null;
    final value = _values[field.name];
    final isEmpty = value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is Set && value.isEmpty);
    return isEmpty ? '${field.label} is required' : null;
  }

  String? validateGroup(String group) {
    for (final f in fieldsForGroup(group)) {
      final error = _mandatoryErrorFor(f);
      if (error != null) return error;
    }
    return null;
  }

  void goToStep(int index) {
    _step = index;
    notifyListeners();
  }

  void nextStep() {
    if (_step < totalSteps - 1) goToStep(_step + 1);
  }

  void prevStep() {
    if (_step > 0) goToStep(_step - 1);
  }

  Future<void> complete() async {
    _submitting = true;
    notifyListeners();
    final businessName = ((_values['Business Name'] as String?) ?? '').trim();
    final firstName = ((_values['First Name'] as String?) ?? '').trim();
    final lastName = ((_values['Last Name'] as String?) ?? '').trim();
    final owner = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final category = _values['Business Category'] as String?;
    await _workspaceRepository.completeSignup(
      name: businessName,
      owner: owner.isNotEmpty ? owner : (_authRepository.currentUser?.name ?? ''),
      email: _authRepository.currentUser?.username ?? '',
      industryId: category ?? 'other',
      size: _size,
      planId: _planId,
      region: _region,
    );
    _submitting = false;
    notifyListeners();
  }
}
