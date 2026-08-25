import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/server_urls.dart';
import '../models/gosure_conversation.dart';
import '../models/gosure_message.dart';
import '../repositories/business_conversations_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/business_chat_service.dart';
import '../services/session_storage.dart';

/// Safety-net poll interval — the list is normally kept fresh by the business-wide SSE
/// stream (see _startLiveUpdates), so this only matters if that connection ever drops
/// silently. Long on purpose: a fixed timer is no longer the primary update mechanism,
/// just a fallback, so it doesn't need to be frequent (or cheap-but-frequent server load).
const _kListPollFallbackInterval = Duration(seconds: 45);

/// Several "something changed" events can arrive in a tight burst (e.g. a multi-part
/// agent reply saving several messages back to back) — collapse them into one refresh
/// instead of firing one per event.
const _kRefreshDebounce = Duration(milliseconds: 400);

class BusinessConversationsViewModel extends ChangeNotifier {
  final BusinessConversationsRepository _repo;
  final SessionStorage _sessionStorage;
  final ApiClient _apiClient;
  Timer? _pollTimer;
  Timer? _refreshDebounceTimer;
  Timer? _reconnectTimer;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  bool _disposed = false;

  BusinessConversationsViewModel(
      this._repo, this._sessionStorage, this._apiClient) {
    _repo.addListener(notifyListeners);
  }

  String? _businessId;
  String? get businessId => _businessId;

  // True until _resolveBusinessId (see init/retryResolve) finds a match — there is no
  // manual-entry fallback, so the UI shows a retry prompt instead while this is true.
  bool get needsBusinessId => _businessId == null || _businessId!.isEmpty;

  List<GosureConversation> get conversations => _repo.conversations;
  bool get loading => _repo.loadingConversations;
  String? get error => _repo.conversationsError;
  bool get hasMore => _repo.hasMoreConversations;

  // How many messages this device has already seen per conversation, so the list can
  // show a "N new" badge (server's live messageCount minus what's already been read).
  final Map<String, int> _seenCounts = {};
  int unreadCountFor(GosureConversation convo) {
    final seen = _seenCounts[convo.conversationId] ?? 0;
    final diff = convo.messageCount - seen;
    return diff > 0 ? diff : 0;
  }

  // GosureConversation.user is a raw id/email — there's no display name at the
  // conversation-list level, only on individual messages (senderName, WhatsApp-style,
  // resolved server-side). Resolved lazily per user group and cached here, since getting
  // it means fetching one conversation's full history.
  final Map<String, String> _userDisplayNames = {};
  final Set<String> _pendingDisplayNameFetches = {};
  String? displayNameFor(String user) => _userDisplayNames[user];

  Future<void> ensureDisplayName(
      String user, GosureConversation anyConversation) async {
    if (_userDisplayNames.containsKey(user) ||
        _pendingDisplayNameFetches.contains(user) ||
        _businessId == null) {
      return;
    }
    // Prefer the server-resolved name already denormalized onto the
    // conversation (see GosureConversation.customerName) — reliable, and
    // needs no extra network round trip. Only conversations created before
    // that resolution existed will lack it, in which case fall back to the
    // older per-message senderName lookup below.
    final serverName = _cleanName(anyConversation.customerName);
    if (serverName != null) {
      _userDisplayNames[user] = serverName;
      notifyListeners();
      return;
    }
    _pendingDisplayNameFetches.add(user);
    try {
      final history = await BusinessChatService.fetchConversationHistory(
          anyConversation.conversationId, _businessId!);
      GosureMessage? customerMessage;
      for (final m in history) {
        if (m.senderKind == GosureMessageSender.customer &&
            (m.senderName?.trim().isNotEmpty ?? false)) {
          customerMessage = m;
          break;
        }
      }
      final name = _cleanName(customerMessage?.senderName);
      if (name != null) {
        _userDisplayNames[user] = name;
        AppLogger.i('BusinessConversationsVM',
            'Resolved display name for $user: $name');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.w('BusinessConversationsVM',
          'Could not resolve display name for $user: $e');
    } finally {
      _pendingDisplayNameFetches.remove(user);
    }
  }

  // The SSO server historically stringified a missing last name as the literal word
  // "null" into the display name — strip that off, same fix as elsewhere it's rendered.
  String? _cleanName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final cleaned =
        raw.replaceAll(RegExp(r'\s+null\b', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }

  Future<void> _syncSeenCounts() async {
    for (final convo in _repo.conversations) {
      _seenCounts[convo.conversationId] =
          await _sessionStorage.readLastSeenCount(convo.conversationId);
    }
    notifyListeners();
  }

  Future<void> init() async {
    await _resolveBusinessId();
    if (!needsBusinessId) {
      await refresh();
      _startLiveUpdates();
      _startPollFallback();
    }
  }

  // Re-attempts auto-resolution after it previously failed to find a match — the only
  // way forward now that there's no manual-entry fallback.
  Future<void> retryResolve() async {
    if (!needsBusinessId) return;
    await _resolveBusinessId();
    if (!needsBusinessId) {
      await refresh();
      _startLiveUpdates();
      _startPollFallback();
    }
  }

  Future<void> _resolveBusinessId() async {
    _businessId = await _sessionStorage.readBusinessId();
    if (needsBusinessId) {
      final session = await _sessionStorage.readSession();
      final email = session?.user.username;
      if (email != null && email.isNotEmpty) {
        try {
          final resolved = await _resolveMyBusinessId(email);
          if (resolved != null && resolved.isNotEmpty) {
            await _sessionStorage.saveBusinessId(resolved);
            _businessId = resolved;
          }
        } catch (e) {
          // Genuinely no account-to-business link exists yet for this signed-in
          // user in that case (not an ACL/API failure — confirmed live: the
          // query itself succeeds cleanly, it just found no match).
          AppLogger.w('BusinessConversationsVM',
              'Could not auto-resolve businessId: $e');
        }
      }
    }
    notifyListeners();
  }

  /// Replaces fixed-interval polling as the primary update mechanism: a persistent SSE
  /// stream pushes one lightweight event per message saved anywhere across this
  /// business's conversations, so the list only re-fetches when something actually
  /// happened. Reconnects (with a short delay) if the stream ever drops — the poll
  /// fallback below covers the gap in the meantime.
  void _startLiveUpdates() {
    if (needsBusinessId) return;
    _eventsSub?.cancel();
    _eventsSub = BusinessChatService.streamBusinessEvents(_businessId!).listen(
      (_) => _debouncedRefresh(),
      onError: (Object e) {
        AppLogger.w('BusinessConversationsVM',
            'Business events stream error, will retry: $e');
        _reconnectLiveUpdatesSoon();
      },
      onDone: () {
        AppLogger.w('BusinessConversationsVM',
            'Business events stream closed, will retry');
        _reconnectLiveUpdatesSoon();
      },
      cancelOnError: true,
    );
  }

  void _reconnectLiveUpdatesSoon() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed || needsBusinessId) return;
      _startLiveUpdates();
    });
  }

  void _debouncedRefresh() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_kRefreshDebounce, () {
      if (!needsBusinessId && !loading) refresh();
    });
  }

  void _startPollFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_kListPollFallbackInterval, (_) {
      if (!needsBusinessId && !loading) refresh();
    });
  }

  /// Finds the Business this signed-in user actually registered. Tries
  /// createdByUsername first (the account that actually created the record),
  /// then falls back to matching the business's own "Work Email" field: a
  /// business owner reasonably expects signing in with the email they
  /// registered the business under to count too, even when that's a public
  /// contact address rather than the literal creator account (e.g. an admin
  /// registered it on their behalf, or the account was later handed to
  /// whoever owns that inbox) — confirmed against real records, e.g.
  /// Cynosure Lutronic's createdByUsername is aidouble@gosure.ai while its
  /// own Work Email is info@cynosure.com, and the business owner signs in
  /// with the latter. Either match is a legitimate "this is your business"
  /// signal — same two-tier logic as the portal's findMyBusiness() (see
  /// jobtypes-api.ts), which this mirrors; that one shipped with the
  /// fallback, this one didn't, which is exactly why business sign-in kept
  /// falling through to the manual "Enter Business ID" prompt regardless of
  /// whether the login was SSO or a plain email.
  /// createdByUsername isn't a `data.*` field, so it can't be server-side
  /// filtered like Work Email could be — fetches the (currently small) full
  /// list and matches client-side instead.
  Future<String?> _resolveMyBusinessId(String email) async {
    final wanted = email.trim().toLowerCase();
    if (wanted.isEmpty) return null;

    final result = await _apiClient.get(
      ServerUrls.businessInstances,
      query: {'pageNumber': '1', 'pageSize': '200', 'filters': '[]'},
    );
    if (result is! Map<String, dynamic>) return null;

    final jobs = result['jobs'] as List?;
    if (jobs == null) return null;

    String? workEmailMatch;
    for (final job in jobs) {
      if (job is! Map<String, dynamic>) continue;
      final owner = job['createdByUsername'];
      if (owner is String && owner.trim().toLowerCase() == wanted) {
        return job['id'] as String?;
      }
      if (workEmailMatch == null) {
        final data = job['data'];
        final workEmail =
            data is Map<String, dynamic> ? data['Work Email'] : null;
        if (workEmail is String && workEmail.trim().toLowerCase() == wanted) {
          workEmailMatch = job['id'] as String?;
        }
      }
    }
    return workEmailMatch;
  }

  Future<void> refresh() async {
    if (needsBusinessId) return;
    await _repo.loadConversations(_businessId!, refresh: true);
    await _syncSeenCounts();
    AppLogger.i('BusinessConversationsVM',
        'Loaded ${conversations.length} conversation(s) for business $_businessId');
  }

  Future<void> loadMore() async {
    if (needsBusinessId) return;
    await _repo.loadMoreConversations(_businessId!);
    await _syncSeenCounts();
    AppLogger.i('BusinessConversationsVM',
        'Loaded more, now ${conversations.length} conversation(s) for business $_businessId');
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _refreshDebounceTimer?.cancel();
    _reconnectTimer?.cancel();
    _eventsSub?.cancel();
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
