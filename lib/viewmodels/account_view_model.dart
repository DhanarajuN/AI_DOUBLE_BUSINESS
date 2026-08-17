import 'package:flutter/foundation.dart';
import '../models/business_profile.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';

class AccountViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final WorkspaceRepository _workspace;
  final SessionStorage _sessionStorage;

  AccountViewModel(this._authRepository, this._workspace, this._sessionStorage) {
    _authRepository.addListener(notifyListeners);
    _workspace.addListener(notifyListeners);
    _loadBusinessData();
  }

  Map<String, dynamic>? _businessData;
  Map<String, dynamic>? get businessData => _businessData;

  Future<void> _loadBusinessData() async {
    _businessData = await _sessionStorage.readBusinessData();
    notifyListeners();
  }

  User? get user => _authRepository.currentUser;
  BusinessProfile? get business => _workspace.business;

  String get accent => _workspace.accent;
  AppThemeMode get themeMode => _workspace.themeMode;
  String get currency => _workspace.currency;

  int get docCount => _workspace.docs.length;
  int get usageIn => _workspace.usageIn;
  int get usageOut => _workspace.usageOut;
  int get usageCalls => _workspace.usageCalls;
  int get bookingCount => _workspace.bookings.length;

  void setAccent(String v) => _workspace.setAccent(v);
  void setThemeMode(AppThemeMode v) => _workspace.setThemeMode(v);

  Future<void> logout() => _authRepository.logout();

  Future<void> resetAll() => _workspace.resetAll();

  @override
  void dispose() {
    _authRepository.removeListener(notifyListeners);
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
