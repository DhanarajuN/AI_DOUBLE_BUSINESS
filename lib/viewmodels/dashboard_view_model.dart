import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/business_profile.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';
import '../services/session_storage.dart';

class DashboardViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;
  final SessionStorage _sessionStorage;

  DashboardViewModel(this._workspace, this._sessionStorage) {
    _workspace.addListener(notifyListeners);
    _loadBusinessData();
  }

  Map<String, dynamic>? _businessData;
  Map<String, dynamic>? get businessData => _businessData;

  Future<void> _loadBusinessData() async {
    _businessData = await _sessionStorage.readBusinessData();
    notifyListeners();
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
