import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../constants/server_urls.dart';
import '../models/business_profile.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';

class AccountViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final WorkspaceRepository _workspace;
  final SessionStorage _sessionStorage;
  final ApiClient _apiClient;

  AccountViewModel(this._authRepository, this._workspace, this._sessionStorage, this._apiClient) {
    _authRepository.addListener(notifyListeners);
    _workspace.addListener(notifyListeners);
    _loadBusinessData();
  }

  Map<String, dynamic>? _businessData;
  Map<String, dynamic>? get businessData => _businessData;

  String? _businessId;
  String? get businessId => _businessId;

  int _bookingCount = 0;

  Future<void> _loadBusinessData() async {
    _businessData = await _sessionStorage.readBusinessData();
    _businessId = await _sessionStorage.readBusinessId();
    notifyListeners();
    await _loadBookingCount();
  }

  Future<void> refreshBusinessData() async {
    final id = _businessId;
    if (id == null || id.isEmpty) return;
    try {
      final result = await _apiClient.get('${ServerUrls.jobInstances}/$id');
      if (result is! Map<String, dynamic>) return;
      final jobs = result['jobs'] as List?;
      if (jobs == null || jobs.isEmpty) return;
      final job = jobs.first;
      if (job is! Map<String, dynamic>) return;
      final data = job['data'];
      if (data is! Map) return;
      _businessData = Map<String, dynamic>.from(data);
      await _sessionStorage.saveBusinessData(_businessData!);
      notifyListeners();
    } catch (e) {
      AppLogger.w('AccountVM', 'Could not refresh business data: $e');
    }
  }

  Future<void> _loadBookingCount() async {
    final businessId = await _sessionStorage.readBusinessId();
    if (businessId == null || businessId.isEmpty) return;
    try {
      final result = await _apiClient.get('${ServerUrls.jobInstances}/$businessId');
      if (result is! Map<String, dynamic>) return;
      final jobs = result['jobs'] as List?;
      if (jobs == null || jobs.isEmpty) return;
      final job = jobs.first;
      if (job is! Map<String, dynamic>) return;
      final subJobs = job[AppConstants.fieldCreatedSubJobs];
      if (subJobs is! List) return;
      _bookingCount = subJobs.whereType<Map>().where((j) {
        final type = j[AppConstants.fieldJobTypeName];
        return type is String && type.toLowerCase() == AppConstants.jobTypeBookings.toLowerCase();
      }).length;
      notifyListeners();
    } catch (e) {
      AppLogger.w('AccountVM', 'Could not load booking count: $e');
    }
  }

  User? get user => _authRepository.currentUser;
  BusinessProfile? get business => _workspace.business;

  String get accent => _workspace.accent;
  AppThemeMode get themeMode => _workspace.themeMode;
  String get currency => _workspace.currency;

  int get usageIn => _workspace.usageIn;
  int get usageOut => _workspace.usageOut;
  int get usageCalls => _workspace.usageCalls;
  int get bookingCount => _bookingCount;

  void setAccent(String v) => _workspace.setAccent(v);
  void setThemeMode(AppThemeMode v) => _workspace.setThemeMode(v);

  Future<void> logout() => _authRepository.logout();

  @override
  void dispose() {
    _authRepository.removeListener(notifyListeners);
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
