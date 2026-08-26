import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/business_profile.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/job_type_instance_service.dart';
import '../services/session_storage.dart';

class CalendarViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;
  final SessionStorage _sessionStorage;
  final ApiClient _apiClient;

  CalendarViewModel(this._workspace, this._sessionStorage, this._apiClient) {
    _workspace.addListener(notifyListeners);
    _loadBookings();
  }

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime get month => _month;

  DateTime? _selected;
  DateTime? get selected => _selected;

  BusinessProfile? get business => _workspace.business;

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> get bookings => _bookings;

  Future<void> refresh() => _loadBookings();

  Future<void> _loadBookings() async {
    final businessData = await _sessionStorage.readBusinessData();
    final businessEmail = (businessData?[AppConstants.fieldBusinessEmail] ?? businessData?['Work Email']) as String?;
    final filter = await resolveBookingsOrdersFilter(_sessionStorage, businessEmail: businessEmail);
    if (filter == null) return;
    _bookings = await fetchJobTypeInstances(_apiClient,
        typeName: AppConstants.jobTypeBookings, filterFieldName: filter.fieldName, filterValue: filter.value);
    notifyListeners();
  }

  void updateOrderStatus(Map<String, dynamic> booking, String status) {
    final id = (booking['id'] ?? booking['_id'])?.toString();
    final match = _bookings.firstWhere(
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
