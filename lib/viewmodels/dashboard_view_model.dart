import 'package:flutter/foundation.dart';
import '../constants/server_urls.dart';
import '../models/booking.dart';
import '../models/business_profile.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/session_storage.dart';

class DashboardViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;
  final SessionStorage _sessionStorage;
  final ApiClient _apiClient;

  DashboardViewModel(this._workspace, this._sessionStorage, this._apiClient) {
    _workspace.addListener(notifyListeners);
    _loadBusinessData();
  }

  Map<String, dynamic>? _businessData;
  Map<String, dynamic>? get businessData => _businessData;

  List<dynamic> _subJobs = [];
  List<dynamic> get subJobs => _subJobs;

  int _countSubJobsOfType(String jobTypeName) => _subJobs.where((j) {
        if (j is! Map) return false;
        final type = j['jobTypeName'];
        return type is String && type.toLowerCase() == jobTypeName.toLowerCase();
      }).length;

  int get bookingsCount => _countSubJobsOfType('Bookings');
  int get ordersCount => _countSubJobsOfType('Orders');

  Future<void> _loadBusinessData() async {
    _businessData = await _sessionStorage.readBusinessData();
    notifyListeners();
    await _loadSubJobs();
  }

  // Sub jobs of the resolved Business record — GET /api/v1/job-instances/:businessId
  // returns {jobs: [{...business fields..., CreatedSubJobs: [{jobTypeName, data, ...}]}]}.
  Future<void> _loadSubJobs() async {
    final businessId = await _sessionStorage.readBusinessId();
    if (businessId == null || businessId.isEmpty) return;
    try {
      final result =
          await _apiClient.get('${ServerUrls.jobInstances}/$businessId');
      if (result is! Map<String, dynamic>) return;
      final jobs = result['jobs'] as List?;
      if (jobs == null || jobs.isEmpty) return;
      final job = jobs.first;
      if (job is! Map<String, dynamic>) return;
      final subJobs = job['CreatedSubJobs'];
      if (subJobs is List) {
        _subJobs = subJobs;
        AppLogger.i('DashboardVM', 'Loaded ${subJobs.length} sub jobs');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.w('DashboardVM', 'Could not load sub jobs: $e');
    }
  }

  BusinessProfile? get business => _workspace.business;
  List<Booking> get bookings => _workspace.bookings;
  List<DocSource> get docs => _workspace.docs;
  int get usageIn => _workspace.usageIn;
  int get usageOut => _workspace.usageOut;
  int get usageCalls => _workspace.usageCalls;
  List<int> get usageDaily => _workspace.usageDaily;
  String get currency => _workspace.currency;

  Future<Booking> simulateBooking() => _workspace.simulateBooking();

  @override
  void dispose() {
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
