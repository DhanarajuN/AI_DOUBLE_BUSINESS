import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../constants/server_urls.dart';
import '../models/business_profile.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/session_storage.dart';

class CalendarViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;
  final SessionStorage _sessionStorage;
  final ApiClient _apiClient;

  CalendarViewModel(this._workspace, this._sessionStorage, this._apiClient) {
    _workspace.addListener(notifyListeners);
    _loadSubJobs();
  }

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime get month => _month;

  DateTime? _selected;
  DateTime? get selected => _selected;

  BusinessProfile? get business => _workspace.business;

  List<dynamic> _subJobs = [];

  List<Map<String, dynamic>> get bookings => _subJobs
      .whereType<Map>()
      .where((j) {
        final type = j[AppConstants.fieldJobTypeName];
        return type is String && type.toLowerCase() == AppConstants.jobTypeBookings.toLowerCase();
      })
      .map((j) => Map<String, dynamic>.from(j))
      .toList();

  Future<void> _loadSubJobs() async {
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
      if (subJobs is List) {
        _subJobs = subJobs;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.w('CalendarVM', 'Could not load sub jobs: $e');
    }
  }

  void updateOrderStatus(Map<String, dynamic> booking, String status) {
    final id = (booking['id'] ?? booking['_id'])?.toString();
    final match = _subJobs.whereType<Map>().firstWhere(
          (j) => (j['id'] ?? j['_id'])?.toString() == id,
          orElse: () => booking,
        );

    match[AppConstants.fieldCurrentJobStatus] = status;

    var data = match['data'];
    if (data is! Map) {
      data = <String, dynamic>{};
      match['data'] = data;
    }
    final key = data.keys.cast<String>().firstWhere(
          (k) => k.toLowerCase() == 'status',
          orElse: () => 'Status',
        );
    data[key] = status;
    notifyListeners();
  }

  void shift(int n) {
    _month = DateTime(_month.year, _month.month + n, 1);
    notifyListeners();
  }

  void goToday() {
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
    notifyListeners();
  }

  void select(DateTime day) {
    _selected = day;
    notifyListeners();
  }

  @override
  void dispose() {
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
