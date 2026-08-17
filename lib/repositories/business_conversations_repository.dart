import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gosure_conversation.dart';
import '../models/gosure_message.dart';
import '../services/app_logger.dart';
import '../services/business_chat_service.dart';
import '../services/friendly_error.dart';
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
  Timer? _eventsReconnectTimer;

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
      conversationsError = friendlyError(e);
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
    _eventsReconnectTimer?.cancel();
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
      await _markSeen(conversation.conversationId);
    } catch (e) {
      if (myGeneration != _openGeneration) return;
      activeError = friendlyError(e);
    } finally {
      if (myGeneration == _openGeneration) {
        loadingActive = false;
        notifyListeners();
      }
    }

    if (myGeneration != _openGeneration)
      return; // superseded before we got to subscribing

    _subscribeToConversationEvents(
        conversation.conversationId, businessId, myGeneration);
  }

  /// Like BusinessConversationsViewModel._startLiveUpdates, but for a single
  /// open conversation's stream: the server sends a heartbeat to keep this
  /// alive, but the underlying HTTP connection can still drop (proxy/network
  /// blip, backend redeploy) — that used to surface as a raw
  /// "ClientException: Connection closed while receiving data" banner with no
  /// recovery, since this subscription had no onDone/reconnect handling
  /// (unlike the conversation-list stream, which already reconnects
  /// silently). Now it does the same: reconnect after a short delay instead
  /// of leaving the viewer stuck on a dead stream, and only surface an error
  /// if the *initial* connection can't be established at all — not on the
  /// resulting exception from that.
  void _subscribeToConversationEvents(
      String conversationId, String businessId, int generation) {
    if (generation != _openGeneration) return;
    _eventsSub = BusinessChatService.streamConversationEvents(
            conversationId, businessId)
        .listen(
      (event) {
        if (generation != _openGeneration) return;
        // A live event proves the connection recovered — clear any stale
        // "connection closed" state a previous drop left behind.
        if (activeError != null) {
          activeError = null;
          notifyListeners();
        }
        _handleEvent(event, generation);
      },
      onError: (Object e) {
        if (generation != _openGeneration) return;
        AppLogger.w('BusinessConversationsRepo',
            'Conversation events stream error, will retry: $e');
        _reconnectConversationEventsSoon(conversationId, businessId, generation);
      },
      onDone: () {
        if (generation != _openGeneration) return;
        AppLogger.w('BusinessConversationsRepo',
            'Conversation events stream closed, will retry');
        _reconnectConversationEventsSoon(conversationId, businessId, generation);
      },
      cancelOnError: true,
    );
  }

  void _reconnectConversationEventsSoon(
      String conversationId, String businessId, int generation) {
    _eventsReconnectTimer?.cancel();
    _eventsReconnectTimer = Timer(const Duration(seconds: 5), () {
      if (generation != _openGeneration) return;
      _subscribeToConversationEvents(conversationId, businessId, generation);
    });
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
    _eventsReconnectTimer?.cancel();
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
      activeError = friendlyError(e);
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
      activeError = friendlyError(e);
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _eventsReconnectTimer?.cancel();
    super.dispose();
  }
}
