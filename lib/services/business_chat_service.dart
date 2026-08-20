import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';
import '../models/gosure_conversation.dart';
import '../models/gosure_message.dart';
import 'app_logger.dart';
import 'session_storage.dart';

class BusinessChatException implements Exception {
  final String message;
  final int? statusCode;
  const BusinessChatException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ConversationsPage {
  final List<GosureConversation> conversations;
  final String? nextCursor;
  const ConversationsPage(this.conversations, this.nextCursor);
}

class BusinessChatService {
  BusinessChatService._();

  /// Fired on a 401 from any real business-conversation call below. Unlike
  /// ApiClient's background bootstrap calls, every call here is something
  /// the business user is actively waiting on (conversation list, message
  /// history, sending a message, the live streams), so a 401 really does
  /// mean the session is dead and should route through a clean sign-out
  /// rather than fail silently with no way back to login.
  static void Function()? onUnauthorized;

  static void _checkAuth(int statusCode) {
    if (statusCode == 401) onUnauthorized?.call();
  }

  static final _sessionStorage = SessionStorage();

  // Gosure routes on this backend expect X-Tenant-Id/X-User-Id/X-Gosure-Token, not the
  // bearer-only headers ApiClient sends elsewhere in this app — mirrors AI_DOUBLE_CUSTOMER's
  // LibreChatService._headers() exactly (X-Gosure-Token is actually the session's access token).
  static Future<Map<String, String>> _headers() async {
    final userId = await _sessionStorage.readUserId();
    final token = await _sessionStorage.readAccessToken();
    return {
      'X-Tenant-Id': ServerUrls.tenant,
      if (userId != null) 'X-User-Id': userId,
      if (token != null) 'X-Gosure-Token': token,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<BusinessChatException> _err(http.Response res) async {
    String detail = '';
    try {
      final j = jsonDecode(res.body);
      detail = (j is Map ? (j['message'] ?? j['error']) : null)?.toString() ??
          res.body;
    } catch (_) {
      detail = res.body;
    }
    return BusinessChatException(
        detail.isEmpty ? 'HTTP ${res.statusCode}' : detail, res.statusCode);
  }

  static Future<ConversationsPage> fetchConversations(
    String businessId, {
    String? cursor,
    int limit = 20,
  }) async {
    final query = {
      'businessId': businessId,
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final uri =
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.gosureConvos}')
            .replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    AppLogger.i('BusinessChat',
        'fetchConversations(businessId=$businessId) -> ${res.statusCode}');
    _checkAuth(res.statusCode);
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (j['conversations'] as List? ?? const [])
        .map((e) => GosureConversation.fromJson(e as Map<String, dynamic>))
        .toList();
    return ConversationsPage(list, j['nextCursor'] as String?);
  }

  // Single-conversation lookup by id — used to deep-link a push notification
  // tap straight into the specific conversation it was about (the list
  // fetch above needs businessId up front and is paginated, so it can't
  // answer "what conversation is this id" on its own).
  static Future<GosureConversation?> fetchConversation(
      String conversationId, String businessId) async {
    final uri = Uri.parse(
            '${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/$conversationId')
        .replace(queryParameters: {'businessId': businessId});
    final res = await http.get(uri, headers: await _headers());
    AppLogger.i('BusinessChat', 'fetchConversation($conversationId) -> ${res.statusCode}');
    _checkAuth(res.statusCode);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    return GosureConversation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // Hydrates a conversation's full history before the persistent event stream (below) takes
  // over for live updates. Uses the gosure-scoped history route (authorized by businessId
  // match), not the generic /api/messages/:conversationId — that one 403s here since it
  // requires conversation.user === req.user.id, and the business isn't the conversation's
  // own LibreChat user, the customer is.
  static Future<List<GosureMessage>> fetchConversationHistory(
      String conversationId, String businessId) async {
    final uri = Uri.parse(
            '${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/$conversationId/${ServerUrls.gosureConvoMessages}')
        .replace(queryParameters: {'businessId': businessId});
    final res = await http.get(uri, headers: await _headers());
    AppLogger.i('BusinessChat',
        'fetchConversationHistory($conversationId) -> ${res.statusCode}');
    _checkAuth(res.statusCode);
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data
        .map((e) => GosureMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Shared plumbing for both persistent SSE streams below. Deliberately NOT an `async*`
  // generator: cancelling a subscription over an async* function only unwinds the
  // generator (and runs its `finally`/closes the client) the NEXT time it reaches an
  // await/yield point — if the server has nothing new to send, that point doesn't
  // come until the next 30s heartbeat, so the real HTTP connection stays open long
  // after the app considers it "closed". Opening and closing several conversations in
  // a row faster than that leaks connections until the browser's per-origin connection
  // limit is hit, at which point EVERY request — including the plain conversation list
  // fetch — queues forever behind the leaked ones. A StreamController with an explicit
  // onCancel that force-closes the client fixes this: cancellation now tears down the
  // underlying socket immediately, not whenever the generator happens to notice.
  static Stream<Map<String, dynamic>> _openEventStream(String label, Uri uri) {
    http.Client? client;
    StreamSubscription<String>? lineSub;
    late final StreamController<Map<String, dynamic>> controller;
    var eventCount = 0;

    Future<void> start() async {
      final c = http.Client();
      client = c;
      AppLogger.i('BusinessChat', '$label opening');
      try {
        final request = http.Request('GET', uri);
        request.headers
            .addAll({...await _headers(), 'Accept': 'text/event-stream'});
        final response = await c.send(request);
        AppLogger.i('BusinessChat', '$label -> ${response.statusCode}');
        _checkAuth(response.statusCode);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          controller.addError(BusinessChatException(
              'Failed to open stream', response.statusCode));
          await controller.close();
          c.close();
          return;
        }

        lineSub = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                // Ignores the ": heartbeat" comment lines (and blank separator lines) — only "data: " matters.
                if (!line.startsWith('data: ')) return;
                final jsonStr = line.substring(6);
                if (jsonStr.isEmpty) return;
                eventCount++;
                controller.add(jsonDecode(jsonStr) as Map<String, dynamic>);
              },
              onError: (Object e) => controller.addError(e),
              onDone: () {
                AppLogger.i(
                    'BusinessChat', '$label closed after $eventCount events');
                controller.close();
              },
            );
      } catch (e) {
        controller.addError(e);
        await controller.close();
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: start,
      onCancel: () {
        AppLogger.i(
            'BusinessChat', '$label cancelled, closing connection immediately');
        lineSub?.cancel();
        client?.close();
      },
    );
    return controller.stream;
  }

  // Persistent per-conversation SSE stream — stays open indefinitely, not just for one AI
  // turn.
  static Stream<Map<String, dynamic>> streamConversationEvents(
      String conversationId, String businessId) {
    final uri = Uri.parse(
            '${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/$conversationId/${ServerUrls.gosureConvoEvents}')
        .replace(queryParameters: {'businessId': businessId});
    return _openEventStream('streamConversationEvents($conversationId)', uri);
  }

  // Business-wide SSE stream: one lightweight "something changed" event per message
  // saved anywhere across this business's conversations. Lets the conversation LIST
  // screen react to real activity instead of polling on a fixed timer regardless of
  // whether anything actually happened.
  static Stream<Map<String, dynamic>> streamBusinessEvents(String businessId) {
    final uri = Uri.parse(
            '${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/${ServerUrls.gosureConvoEvents}')
        .replace(queryParameters: {'businessId': businessId});
    return _openEventStream('streamBusinessEvents($businessId)', uri);
  }

  static Future<bool> setAgentChatMode(
      String conversationId, String businessId, bool value) async {
    final uri = Uri.parse(
        '${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/$conversationId/${ServerUrls.gosureConvoAgentMode}');
    final res = await http.patch(
      uri,
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'agentChatMode': value, 'businessId': businessId}),
    );
    AppLogger.i('BusinessChat',
        'setAgentChatMode($conversationId, $value) -> ${res.statusCode}');
    _checkAuth(res.statusCode);
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return j['agentChatMode'] as bool? ?? value;
  }

  static Future<GosureMessage> sendBusinessMessage(
    String conversationId,
    String businessId,
    String text, {
    String? parentMessageId,
  }) async {
    final uri = Uri.parse(
        '${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/$conversationId/${ServerUrls.gosureConvoMessages}');
    final res = await http.post(
      uri,
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'businessId': businessId,
        if (parentMessageId != null) 'parentMessageId': parentMessageId,
      }),
    );
    AppLogger.i('BusinessChat',
        'sendBusinessMessage($conversationId) -> ${res.statusCode}');
    _checkAuth(res.statusCode);
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    return GosureMessage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
