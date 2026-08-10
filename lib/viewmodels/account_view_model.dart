import 'package:flutter/foundation.dart';
import '../models/business_profile.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../services/llm_service.dart';
import '../theme/app_theme.dart';

class AccountViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final WorkspaceRepository _workspace;

  AccountViewModel(this._authRepository, this._workspace) {
    _authRepository.addListener(notifyListeners);
    _workspace.addListener(notifyListeners);
  }

  bool _obscureKey = true;
  bool get obscureKey => _obscureKey;

  bool _testing = false;
  bool get testing => _testing;

  User? get user => _authRepository.currentUser;
  BusinessProfile? get business => _workspace.business;

  String get provider => _workspace.provider;
  String get apiKey => _workspace.apiKey;
  String get model => _workspace.model;
  String get brand => _workspace.brand;
  String get accent => _workspace.accent;
  AppThemeMode get themeMode => _workspace.themeMode;
  String get currency => _workspace.currency;
  bool get keyReady => _workspace.keyReady;

  int get docCount => _workspace.docs.length;
  int get usageIn => _workspace.usageIn;
  int get usageOut => _workspace.usageOut;
  int get usageCalls => _workspace.usageCalls;
  int get bookingCount => _workspace.bookings.length;

  void toggleObscureKey() {
    _obscureKey = !_obscureKey;
    notifyListeners();
  }

  void setProvider(String v) => _workspace.setProvider(v);
  void setApiKey(String v) => _workspace.setApiKey(v);
  void setModel(String v) => _workspace.setModel(v);
  void setBrand(String v) => _workspace.setBrand(v);
  void setAccent(String v) => _workspace.setAccent(v);
  void setThemeMode(AppThemeMode v) => _workspace.setThemeMode(v);

  Future<void> testConnection() async {
    _testing = true;
    notifyListeners();
    try {
      await LlmService.call(
        provider: provider,
        apiKey: apiKey,
        model: model.trim().isNotEmpty ? model.trim() : kProviders[provider]!.model,
        system: 'You are a connection tester. Reply with exactly: ok',
        messages: const [
          {'role': 'user', 'content': 'Say ok'},
        ],
      );
    } finally {
      _testing = false;
      notifyListeners();
    }
  }

  Future<void> logout() => _authRepository.logout();

  Future<void> resetAll() => _workspace.resetAll();

  @override
  void dispose() {
    _authRepository.removeListener(notifyListeners);
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
