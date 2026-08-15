import 'package:flutter/foundation.dart';
import '../models/gosure_conversation.dart';
import '../models/gosure_message.dart';
import '../repositories/business_conversations_repository.dart';

class ConversationDetailViewModel extends ChangeNotifier {
  final BusinessConversationsRepository _repo;
  final String businessId;

  ConversationDetailViewModel(this._repo, this.businessId) {
    _repo.addListener(notifyListeners);
  }

  GosureConversation? get conversation => _repo.activeConversation;
  List<GosureMessage> get messages => _repo.activeMessages;
  bool get loading => _repo.loadingActive;
  String? get error => _repo.activeError;
  bool get agentChatMode => conversation?.agentChatMode ?? true;

  bool _togglingMode = false;
  bool get togglingMode => _togglingMode;
  bool _sending = false;
  bool get sending => _sending;

  Future<void> open(GosureConversation conversation) =>
      _repo.openConversation(conversation, businessId);

  Future<void> toggleAgentChatMode(bool value) async {
    if (_togglingMode) return;
    _togglingMode = true;
    notifyListeners();
    try {
      await _repo.setAgentChatMode(businessId, value);
    } finally {
      _togglingMode = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    if (_sending || text.trim().isEmpty) return;
    _sending = true;
    notifyListeners();
    try {
      await _repo.sendMessage(businessId, text);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> close() => _repo.closeConversation();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
