import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attachment_file.dart';
import '../models/field_rule.dart';
import '../models/job_type_schema.dart';
import '../services/api_client.dart';
import '../services/field_rule_service.dart';
import '../services/job_type_schema_service.dart';

class JobInstanceEditViewModel extends ChangeNotifier {
  final ApiClient _apiClient;
  final String jobTypeName;
  final String instanceId;
  final Map<String, dynamic> _rawInitialData;
  final String? currentUserEmail;

  JobInstanceEditViewModel(this._apiClient,
      {required this.jobTypeName, required this.instanceId, Map<String, dynamic>? initialData, this.currentUserEmail})
      : _rawInitialData = initialData ?? const {} {
    _loadSchema();
  }

  JobTypeSchema? _schema;
  JobTypeSchema? get schema => _schema;

  bool _loadingSchema = false;
  bool get loadingSchema => _loadingSchema;

  bool _schemaFailed = false;
  bool get schemaFailed => _schemaFailed;

  bool _saving = false;
  bool get saving => _saving;

  final Map<String, dynamic> _values = {};
  dynamic valueOf(String fieldName) => _values[fieldName];

  final Map<String, FieldRule> _fieldRules = {};
  final Map<String, int> _sectionCounts = {};

  int sectionCountFor(String groupName) => _sectionCounts[groupName] ?? 1;

  void addSection(String groupName) {
    _sectionCounts[groupName] = sectionCountFor(groupName) + 1;
    notifyListeners();
  }

  void removeSection(String groupName, int index) {
    final count = sectionCountFor(groupName);
    if (count <= 1) return;
    final s = _schema;
    if (s != null) {
      for (final f in s.fieldsInGroup(groupName)) {
        final list = _values[f.name];
        if (list is List && index < list.length) list.removeAt(index);
      }
    }
    _sectionCounts[groupName] = count - 1;
    notifyListeners();
  }

  List<dynamic> _sectionListFor(String fieldName) {
    final existing = _values[fieldName];
    if (existing is List) return existing;
    final list = <dynamic>[];
    _values[fieldName] = list;
    return list;
  }

  void _ensureLength(List<dynamic> list, int index) {
    while (list.length <= index) {
      list.add(null);
    }
  }

  dynamic valueAt(String fieldName, int index) {
    // ADD_ORDER is a computed 1-based position within its group, not
    // something stored per section — it stays correct even as sections are
    // added, removed, or reordered.
    if (_schema?.fieldNamed(fieldName)?.isAddOrderCounter ?? false) {
      return (index + 1).toString();
    }
    final list = _values[fieldName];
    if (list is List && index < list.length) return list[index];
    return null;
  }

  void setTextValueAt(String fieldName, int index, String value) {
    final list = _sectionListFor(fieldName);
    _ensureLength(list, index);
    list[index] = value;
    _clearDependents(fieldName, index: index);
    notifyListeners();
  }

  void pickSingleValueAt(JobTypeField field, int index, JobTypeFieldOption option) {
    final list = _sectionListFor(field.name);
    _ensureLength(list, index);
    list[index] = option.submissionValue;
    _clearDependents(field.name, index: index);
    notifyListeners();
  }

  void toggleMultiValueAt(JobTypeField field, int index, JobTypeFieldOption option) {
    final list = _sectionListFor(field.name);
    _ensureLength(list, index);
    final current = Set<String>.from((list[index] as Set<String>?) ?? const <String>{});
    if (!current.remove(option.submissionValue)) current.add(option.submissionValue);
    list[index] = current;
    _clearDependents(field.name, index: index);
    notifyListeners();
  }

  List<JobTypeFieldOption> optionsForFieldAt(JobTypeField field, int index) {
    final s = _schema;
    if (s == null) return const [];
    final parentName = _parentFieldNameOf(field);
    final parentRaw = parentName == null ? null : valueAt(parentName, index)?.toString();
    final parentLabel = parentRaw == null ? null : JobTypeFieldOption.labelOf(parentRaw);
    return s.optionsFor(field, parentSelectionLabel: parentLabel);
  }

  final Set<String> _hiddenFieldNames = {};

  List<JobTypeField> get editableFields {
    final s = _schema;
    if (s == null) return const [];
    final visible = s.fields.where((f) => !f.isSubJob && !f.isReport && !_hiddenFieldNames.contains(f.name)).toList();

    // A field carrying a visibility rule (e.g. a Selection whose rule
    // string contains "rule:") controls a set of groups — only the group
    // mapped to its currently selected value stays visible, every other
    // group that rule controls is hidden until a value maps to it.
    final hiddenGroups = <String>{};
    for (final f in s.fields) {
      final rule = f.rule;
      if (rule.isEmpty || !rule.contains('rule:')) continue;
      final fieldRule = _fieldRules[rule];
      if (fieldRule == null) continue;
      final rawValue = _values[f.name]?.toString();
      final selectedLabel = rawValue == null ? null : JobTypeFieldOption.labelOf(rawValue);
      final groupToShow = fieldRule.groupToShowFor(selectedLabel);
      for (final g in fieldRule.controlledGroups) {
        if (g != groupToShow) hiddenGroups.add(g);
      }
    }
    if (hiddenGroups.isEmpty) return visible;
    return visible.where((f) => !hiddenGroups.contains(f.groupName)).toList();
  }

  // Group-rendering call sites should use this instead of reading
  // schema.fieldsInGroup directly, so individually hidden fields (see
  // _applyFieldWiseHide below) and SubJob placeholders stay filtered out
  // consistently everywhere, not just in the flat editableFields list.
  List<JobTypeField> fieldsForGroup(String group) {
    final s = _schema;
    if (s == null) return const [];
    return s
        .fieldsInGroup(group)
        .where((f) => !f.isSubJob && !f.isReport && !_hiddenFieldNames.contains(f.name))
        .toList();
  }

  Map<String, dynamic> _normalizeInitialValues(JobTypeSchema schema, Map<String, dynamic> raw) {
    final values = <String, dynamic>{};
    for (final entry in raw.entries) {
      final field = schema.fieldNamed(entry.key);
      final value = entry.value;
      if (field != null && field.isFile) {
        values[entry.key] = _asAttachmentList(value);
      } else if (field != null && field.enableAddMore && value is List) {
        values[entry.key] = List<dynamic>.from(value);
        if (value.length > sectionCountFor(field.groupName)) {
          _sectionCounts[field.groupName] = value.length;
        }
      } else if (field != null && field.multiselect && value is List) {
        values[entry.key] = Set<String>.from(value.map((e) => e.toString()));
      } else {
        values[entry.key] = value;
      }
    }
    return values;
  }

  // Attachment values can arrive flat ([{fileUrl,...}]), nested ([[{...}]]),
  // or as a single map ({fileUrl,...}) depending on how the field was saved —
  // collect every map found at any depth rather than assuming one shape.
  List<AttachmentFile> _asAttachmentList(dynamic value) {
    final maps = <Map>[];
    void collect(dynamic node) {
      if (node is Map) {
        maps.add(node);
      } else if (node is List) {
        for (final child in node) {
          collect(child);
        }
      }
    }

    collect(value);
    return maps.map((m) => AttachmentFile.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  String? _parentFieldNameOf(JobTypeField field) {
    final s = _schema;
    if (s == null) return null;
    for (final f in s.fields) {
      if (f.dependentFields == field.name) return f.name;
    }
    return null;
  }

  List<JobTypeFieldOption> optionsForField(JobTypeField field) {
    final s = _schema;
    if (s == null) return const [];
    final parentName = _parentFieldNameOf(field);
    final parentRaw = parentName == null ? null : _values[parentName]?.toString();
    final parentLabel = parentRaw == null ? null : JobTypeFieldOption.labelOf(parentRaw);
    return s.optionsFor(field, parentSelectionLabel: parentLabel);
  }

  void setTextValue(String fieldName, String value) {
    _values[fieldName] = value;
    _clearDependents(fieldName);
    notifyListeners();
  }

  void pickSingleValue(JobTypeField field, JobTypeFieldOption option) {
    _values[field.name] = option.submissionValue;
    _clearDependents(field.name);
    notifyListeners();
  }

  void toggleMultiValue(JobTypeField field, JobTypeFieldOption option) {
    final current = Set<String>.from((_values[field.name] as Set<String>?) ?? const <String>{});
    if (!current.remove(option.submissionValue)) current.add(option.submissionValue);
    _values[field.name] = current;
    _clearDependents(field.name);
    if (field.isRadioOrCheckbox) _applyFieldWiseHide(field);
    notifyListeners();
  }

  List<AttachmentFile> attachmentsFor(String fieldName) =>
      (_values[fieldName] as List<AttachmentFile>?) ?? const [];

  void addAttachments(String fieldName, List<AttachmentFile> files) {
    final current = List<AttachmentFile>.from(attachmentsFor(fieldName))..addAll(files);
    _values[fieldName] = current;
    notifyListeners();
  }

  void removeAttachment(String fieldName, AttachmentFile file) {
    final current = List<AttachmentFile>.from(attachmentsFor(fieldName))..remove(file);
    _values[fieldName] = current;
    notifyListeners();
  }

  // Any field that declares this one as its dependency gets its stale
  // value cleared — for a Selection field that recomputes its options from
  // the new parent value (see optionsForField), and for anything else as a
  // straightforward "the context changed, re-enter this" reset.
  void _clearDependents(String fieldName, {int? index}) {
    final s = _schema;
    if (s == null) return;
    for (final f in s.fields) {
      if (f.dependentFields != fieldName) continue;
      if (f.enableAddMore && index != null) {
        final list = _values[f.name];
        if (list is List && index < list.length) list[index] = null;
      } else {
        _values.remove(f.name);
      }
    }
  }

  // A Radio_OR_CheckBox field in checkbox (multiselect) mode can carry a
  // rule string shaped "<value>:field1,field2|<value2>:field3~...", parsed
  // (not fetched from the backend — this is purely local, unlike the
  // group-visibility rules above): if the field's own current selection
  // matches one of the value prefixes, the fields listed after ":" for that
  // clause are unhidden; otherwise every field across every clause is
  // hidden. Only the last "~"-separated segment of the rule is live.
  void _applyFieldWiseHide(JobTypeField field) {
    final ruleValue = field.rule;
    if (ruleValue.isEmpty) return;
    final unhideRules = ruleValue.split('~').last;
    final groups = unhideRules.contains('|') ? unhideRules.split('|') : [unhideRules];

    final dataValue = _values[field.name];
    var hasMatchingGroup = false;
    String? matchedValue;

    if (dataValue is Set && dataValue.isNotEmpty) {
      for (final val in dataValue) {
        final value = val.toString().trim().split('(').first;
        if (groups.any((g) => g.toLowerCase().startsWith(value.toLowerCase()))) {
          hasMatchingGroup = true;
          matchedValue = value;
          break;
        }
      }
    } else if (dataValue != null && dataValue.toString().trim().isNotEmpty && dataValue.toString() != 'null') {
      final value = dataValue.toString().trim().split('(').first;
      if (groups.any((g) => g.toLowerCase().startsWith(value.toLowerCase()))) {
        hasMatchingGroup = true;
        matchedValue = value;
      }
    }

    if (!hasMatchingGroup) {
      _hideAllFieldsWise(groups);
    } else {
      _unhideRelevantFieldsWise(groups, matchedValue!);
    }
  }

  void _hideAllFieldsWise(List<String> groups) {
    final s = _schema;
    if (s == null) return;
    for (final group in groups) {
      final parts = group.split(':');
      if (parts.length <= 1) continue;
      for (final namePart in parts[1].split(',')) {
        for (final f in s.fields.where((f) => f.name.contains(namePart))) {
          _hiddenFieldNames.add(f.name);
        }
      }
    }
  }

  void _unhideRelevantFieldsWise(List<String> groups, String fieldValue) {
    final s = _schema;
    if (s == null) return;
    for (final group in groups) {
      final parts = group.split(':');
      if (parts.length <= 1 || parts[0] != fieldValue) continue;
      for (final namePart in parts[1].split(',')) {
        for (final f in s.fields.where((f) => f.name.contains(namePart))) {
          _hiddenFieldNames.remove(f.name);
        }
      }
    }
  }

  Future<void> _loadSchema() async {
    _loadingSchema = true;
    _schemaFailed = false;
    notifyListeners();
    final result = await fetchJobTypeSchema(_apiClient, jobTypeName);
    _schema = result;
    _schemaFailed = result == null;
    if (result != null) {
      _values.addAll(_normalizeInitialValues(result, _rawInitialData));
      _applyAutoValues(result);
    }
    _loadingSchema = false;
    notifyListeners();
    if (result != null) unawaited(_loadFieldRules(result));
  }

  Future<void> _loadFieldRules(JobTypeSchema schema) async {
    for (final f in schema.fields) {
      final rule = f.rule;
      if (rule.isEmpty || !rule.contains('rule:') || _fieldRules.containsKey(rule)) continue;
      try {
        final fetched = await fetchFieldRule(_apiClient, rule);
        if (fetched != null) {
          _fieldRules[rule] = fetched;
          notifyListeners();
        }
      } catch (_) {
        // Best-effort — a field whose rule can't be resolved just stays
        // fully visible rather than blocking the rest of the form.
      }
    }
  }

  // Auto_Date/Auto_Date_Time/Read_Only_Login_Email are populated once from
  // context the user never types in, then displayed read-only — never
  // overwritten if a value already came back with the record.
  void _applyAutoValues(JobTypeSchema schema) {
    final now = DateTime.now();
    for (final f in schema.fields) {
      if (_values[f.name] != null) continue;
      if (f.isAutoDate || f.isAutoDateTime) {
        _values[f.name] = now.toIso8601String();
      } else if (f.isReadOnlyLoginEmail && currentUserEmail != null) {
        _values[f.name] = currentUserEmail;
      }
    }
  }

  Future<void> retryLoadSchema() => _loadSchema();

  static final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Set) return value.isEmpty;
    if (value is List<AttachmentFile>) return !value.any((f) => f.isUploaded);
    if (value is List) return value.isEmpty;
    return false;
  }

  String? _mandatoryErrorForValue(JobTypeField field, dynamic value) {
    if (!field.mandatory) return null;
    if (_isEmptyValue(value)) return '${field.label} is required';
    if (field.isEmail && value is String && !_emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    if (field.isPhoneNumber && value is String && value.trim().length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? validate() {
    for (final f in editableFields) {
      if (f.enableAddMore) {
        final count = sectionCountFor(f.groupName);
        for (var i = 0; i < count; i++) {
          final error = _mandatoryErrorForValue(f, valueAt(f.name, i));
          if (error != null) return error;
        }
        continue;
      }
      final error = _mandatoryErrorForValue(f, _values[f.name]);
      if (error != null) return error;
    }
    return null;
  }

  Map<String, dynamic> buildSubmissionData() {
    final data = <String, dynamic>{};
    for (final entry in _values.entries) {
      final value = entry.value;
      if (value is Set<String>) {
        data[entry.key] = value.toList();
      } else if (value is List<AttachmentFile>) {
        data[entry.key] = value.where((f) => f.isUploaded).map((f) => f.toJson()).toList();
      } else {
        data[entry.key] = value;
      }
    }
    // ADD_ORDER fields are computed on read (see valueAt) rather than
    // stored, so they need materializing here rather than falling out of
    // the loop above.
    for (final f in _schema?.fields ?? const <JobTypeField>[]) {
      if (!f.isAddOrderCounter) continue;
      data[f.name] = List.generate(sectionCountFor(f.groupName), (i) => (i + 1).toString());
    }
    return data;
  }

  Future<String?> save(Future<void> Function(String instanceId, Map<String, dynamic> data) onSave) async {
    final error = validate();
    if (error != null) return error;

    _saving = true;
    notifyListeners();
    String? result;
    try {
      await onSave(instanceId, buildSubmissionData());
    } catch (e) {
      result = e.toString();
    }
    _saving = false;
    notifyListeners();
    return result;
  }
}
