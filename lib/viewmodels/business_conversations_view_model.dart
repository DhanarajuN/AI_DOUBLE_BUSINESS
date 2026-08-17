import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gosure_conversation.dart';
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

  // See SessionStorage.readBusinessId for the placeholder note. init() now tries to resolve
  // this automatically first (see _resolveMyBusinessId) — the manual prompt below is only the
  // fallback for when that lookup fails or finds nothing.
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

  Future<void> _syncSeenCounts() async {
    for (final convo in _repo.conversations) {
      _seenCounts[convo.conversationId] =
          await _sessionStorage.readLastSeenCount(convo.conversationId);
    }
    notifyListeners();
  }

  Future<void> init() async {
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
          // Falls through to the manual-entry prompt. Genuinely no account-
          // to-business link exists yet for this signed-in user in that case
          // (not an ACL/API failure — confirmed live: the query itself
          // succeeds cleanly, it just found no match).
          AppLogger.w('BusinessConversationsVM',
              'Could not auto-resolve businessId: $e');
        }
      }
    }
    notifyListeners();
    if (!needsBusinessId) {
      await refresh();
      _startLiveUpdates();
      _startPollFallback();
    }
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
      '/api/v1/job-types/name/Business/instances',
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

  Future<void> setBusinessId(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    await _sessionStorage.saveBusinessId(trimmed);
    _businessId = trimmed;
    notifyListeners();
    await refresh();
    _startLiveUpdates();
    _startPollFallback();
  }

  Future<void> refresh() async {
    if (needsBusinessId) return;
    await _repo.loadConversations(_businessId!, refresh: true);
    await _syncSeenCounts();
  }

  Future<void> loadMore() async {
    if (needsBusinessId) return;
    await _repo.loadMoreConversations(_businessId!);
    await _syncSeenCounts();
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
