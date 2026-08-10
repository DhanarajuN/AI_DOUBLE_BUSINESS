import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/business_profile.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';

class DashboardViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;

  DashboardViewModel(this._workspace) {
    _workspace.addListener(notifyListeners);
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
