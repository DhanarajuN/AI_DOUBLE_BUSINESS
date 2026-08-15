import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gosure_conversation.dart';
import '../models/gosure_message.dart';
import '../services/business_chat_service.dart';
import '../services/session_storage.dart';

class BusinessConversationsRepository extends ChangeNotifier {
  final SessionStorage _sessionStorage;
  BusinessConversationsRepository(this._sessionStorage);

  List<GosureConversation> conversations = [];
  bool loadingConversations = false;
  String? conversationsError;
  String? _nextCursor;
  bool get hasMoreConversations => _nextCursor != null;

  GosureConversation? activeConversation;
  List<GosureMessage> activeMessages = [];
  bool loadingActive = false;
  String? activeError;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  // Bumped on every openConversation()/closeConversation() call. History fetches and SSE
  // subscriptions are async and can resolve out of order (e.g. a quick open-A, back,
  // open-B can have A's slower request land after B's) — each async continuation checks
  // this before touching state, so a stale response from an abandoned open() can never
  // clobber whatever conversation is actually active now.
  int _openGeneration = 0;

  Future<void> loadConversations(String businessId,
      {bool refresh = false}) async {
    if (loadingConversations) return;
    loadingConversations = true;
    if (refresh) {
      conversations = [];
      _nextCursor = null;
    }
    conversationsError = null;
    notifyListeners();
    try {
      final page = await BusinessChatService.fetchConversations(businessId,
          cursor: refresh ? null : _nextCursor);
      conversations = refresh
          ? page.conversations
          : [...conversations, ...page.conversations];
      _nextCursor = page.nextCursor;
    } catch (e) {
      conversationsError = e.toString();
    } finally {
      loadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreConversations(String businessId) async {
    if (!hasMoreConversations || loadingConversations) return;
    await loadConversations(businessId);
  }

  Future<void> openConversation(
      GosureConversation conversation, String businessId) async {
    final myGeneration = ++_openGeneration;
    unawaited(_eventsSub?.cancel());
    _eventsSub = null;
    activeConversation = conversation;
    activeMessages = [];
    activeError = null;
    loadingActive = true;
    notifyListeners();

    try {
      final history = await BusinessChatService.fetchConversationHistory(
          conversation.conversationId, businessId);
      if (myGeneration != _openGeneration)
        return; // superseded by a newer open() while this was in flight
      activeMessages = history;
      // Awaited, not fire-and-forget — a save that's still in flight when the tab closes
      // or refreshes is a save that never happens, which is exactly the "badge came back
      // after refresh" bug. This blocks nothing user-visible; the messages are already
      // on screen from the notifyListeners() calls around this block.
      await _markSeen(conversation.conversationId);
    } catch (e) {
      // Best-effort hydrate — don't block the live stream below if history fails to load.
      if (myGeneration != _openGeneration) return;
      activeError = e.toString();
    } finally {
      if (myGeneration == _openGeneration) {
        loadingActive = false;
        notifyListeners();
      }
    }

    if (myGeneration != _openGeneration)
      return; // superseded before we got to subscribing

    _eventsSub = BusinessChatService.streamConversationEvents(
            conversation.conversationId, businessId)
        .listen(
      (event) => _handleEvent(event, myGeneration),
      onError: (Object e) {
        if (myGeneration != _openGeneration) return;
        activeError = e.toString();
        notifyListeners();
      },
    );
  }

  void _handleEvent(Map<String, dynamic> event, int generation) {
    if (generation != _openGeneration)
      return; // event from a conversation we've since left
    final type = event['type'] as String?;
    if (type == 'message.created') {
      final raw = event['message'] as Map<String, dynamic>?;
      if (raw == null) return;
      final message = GosureMessage.fromJson(raw);
      final dupe = message.messageId.isNotEmpty &&
          activeMessages.any((m) => m.messageId == message.messageId);
      if (dupe) return;
      activeMessages = [...activeMessages, message];
      // Conversation is open on screen right now, so a message arriving live counts
      // as seen immediately — no reason to badge something the business is looking at.
      unawaited(_markSeen(
          activeConversation?.conversationId ?? message.conversationId ?? ''));
      notifyListeners();
    } else if (type == 'agent-mode.changed') {
      final value = event['agentChatMode'] as bool?;
      final convo = activeConversation;
      if (value == null || convo == null) return;
      activeConversation = convo.copyWith(agentChatMode: value);
      _patchConversationInList(activeConversation!);
      notifyListeners();
    }
  }

  Future<void> _markSeen(String conversationId) async {
    if (conversationId.isEmpty) return;
    await _sessionStorage.saveLastSeenCount(
        conversationId, activeMessages.length);
  }

  void _patchConversationInList(GosureConversation updated) {
    final idx = conversations
        .indexWhere((c) => c.conversationId == updated.conversationId);
    if (idx == -1) return;
    conversations = [...conversations]..[idx] = updated;
  }

  Future<void> closeConversation() async {
    _openGeneration++; // invalidates any openConversation() call still in flight
    await _eventsSub?.cancel();
    _eventsSub = null;
    activeConversation = null;
    activeMessages = [];
    activeError = null;
    loadingActive = false;
    notifyListeners();
  }

  Future<void> setAgentChatMode(String businessId, bool value) async {
    final convo = activeConversation;
    if (convo == null) return;
    try {
      final applied = await BusinessChatService.setAgentChatMode(
          convo.conversationId, businessId, value);
      activeConversation = convo.copyWith(agentChatMode: applied);
      _patchConversationInList(activeConversation!);
      notifyListeners();
    } catch (e) {
      activeError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendMessage(String businessId, String text) async {
    final convo = activeConversation;
    final trimmed = text.trim();
    if (convo == null || trimmed.isEmpty) return;
    final parentId =
        activeMessages.isNotEmpty ? activeMessages.last.messageId : null;
    try {
      // Don't append locally — the persistent SSE subscription above echoes this message back
      // via message.created, which is the single source of truth for message ordering.
      await BusinessChatService.sendBusinessMessage(
        convo.conversationId,
        businessId,
        trimmed,
        parentMessageId:
            (parentId != null && parentId.isNotEmpty) ? parentId : null,
      );
    } catch (e) {
      activeError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }
}
