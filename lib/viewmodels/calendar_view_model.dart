import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/business_profile.dart';
import '../repositories/workspace_repository.dart';

class CalendarViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;

  CalendarViewModel(this._workspace) {
    _workspace.addListener(notifyListeners);
  }

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime get month => _month;

  DateTime? _selected;
  DateTime? get selected => _selected;

  BusinessProfile? get business => _workspace.business;
  List<Booking> get bookings => _workspace.bookings;

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

  Future<Booking> addBookingOn(DateTime day) => _workspace.addBookingOn(day);

  @override
  void dispose() {
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
