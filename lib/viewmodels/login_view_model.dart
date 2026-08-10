import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  LoginViewModel(this._authRepository) {
    _authRepository.addListener(notifyListeners);
  }

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  bool get isLoading => _authRepository.isLoading;
  String? get errorMessage => _authRepository.errorMessage;

  Future<bool> login({required String username, required String password}) {
    return _authRepository.login(username: username, password: password);
  }

  Future<bool> loginWithGoogle() {
    return _authRepository.loginWithGoogle();
  }

  @override
  void dispose() {
    _authRepository.removeListener(notifyListeners);
    super.dispose();
  }
}
