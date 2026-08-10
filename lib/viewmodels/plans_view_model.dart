import 'package:flutter/foundation.dart';
import '../repositories/workspace_repository.dart';

class PlansViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;

  PlansViewModel(this._workspace) {
    _workspace.addListener(notifyListeners);
  }

  String get currency => _workspace.currency;
  String? get currentPlanId => _workspace.business?.planId;

  void setCurrency(String c) => _workspace.setCurrency(c);

  Future<void> choosePlan(String planId) => _workspace.setPlan(planId);

  @override
  void dispose() {
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
