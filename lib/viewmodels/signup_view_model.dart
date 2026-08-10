import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';

class SignupViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final WorkspaceRepository _workspaceRepository;

  SignupViewModel(this._authRepository, this._workspaceRepository);

  int _step = 1;
  int get step => _step;

  String? _industryId;
  String? get industryId => _industryId;

  String _size = '';
  String get size => _size;

  String _region = 'in';
  String get region => _region;

  String _planId = 'growth';
  String get planId => _planId;

  bool _submitting = false;
  bool get submitting => _submitting;

  String? get initialOwnerName => _authRepository.currentUser?.name;

  void pickIndustry(String id) {
    _industryId = id;
    notifyListeners();
  }

  void pickSize(String s) {
    _size = s;
    notifyListeners();
  }

  void pickRegion(String r) {
    _region = r;
    notifyListeners();
  }

  void pickPlan(String id) {
    _planId = id;
    notifyListeners();
  }

  String? validateStep1(String businessName) {
    if (businessName.trim().isEmpty) return 'Enter your business name';
    if (_industryId == null) return 'Pick your industry';
    return null;
  }

  void goToStep2() {
    _step = 2;
    notifyListeners();
  }

  void goToStep1() {
    _step = 1;
    notifyListeners();
  }

  Future<void> complete({required String name, required String owner}) async {
    _submitting = true;
    notifyListeners();
    await _workspaceRepository.completeSignup(
      name: name.trim(),
      owner: owner.trim(),
      email: _authRepository.currentUser?.username ?? '',
      industryId: _industryId!,
      size: _size,
      planId: _planId,
      region: _region,
    );
    _submitting = false;
    notifyListeners();
  }
}
