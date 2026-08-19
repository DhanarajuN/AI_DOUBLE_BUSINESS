import 'package:flutter/material.dart';
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

  String? _businessCategoryId;
  String? get businessCategoryId => _businessCategoryId;

  final Set<String> _subCategories = {};
  Set<String> get subCategories => _subCategories;

  final Set<String> _availabilityDays = {};
  Set<String> get availabilityDays => _availabilityDays;

  TimeOfDay? _availabilityFrom;
  TimeOfDay? get availabilityFrom => _availabilityFrom;

  TimeOfDay? _availabilityTo;
  TimeOfDay? get availabilityTo => _availabilityTo;

  String? _businessType;
  String? get businessType => _businessType;

  String? _primaryGoal;
  String? get primaryGoal => _primaryGoal;

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

  void pickBusinessCategory(String id) {
    _businessCategoryId = id;
    _subCategories.clear();
    notifyListeners();
  }

  void toggleSubCategory(String name) {
    if (!_subCategories.remove(name)) _subCategories.add(name);
    notifyListeners();
  }

  void toggleAvailabilityDay(String day) {
    if (!_availabilityDays.remove(day)) _availabilityDays.add(day);
    notifyListeners();
  }

  void setAvailabilityFrom(TimeOfDay time) {
    _availabilityFrom = time;
    notifyListeners();
  }

  void setAvailabilityTo(TimeOfDay time) {
    _availabilityTo = time;
    notifyListeners();
  }

  void pickBusinessType(String type) {
    _businessType = type;
    notifyListeners();
  }

  void pickPrimaryGoal(String goal) {
    _primaryGoal = goal;
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

  String? validateStep2() {
    if (_businessCategoryId == null) return 'Pick your business category';
    if (_subCategories.isEmpty) return 'Pick at least one sub-category';
    return null;
  }

  void goToStep1() {
    _step = 1;
    notifyListeners();
  }

  void goToStep2() {
    _step = 2;
    notifyListeners();
  }

  void goToStep3() {
    _step = 3;
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
