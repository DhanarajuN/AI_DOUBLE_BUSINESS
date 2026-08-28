import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';
import '../firebase_options.dart';
import '../routes/app_routes.dart';
import '../views/conversation_detail_view.dart';
import 'app_logger.dart';
import 'business_chat_service.dart';
import 'session_storage.dart';

/// Must be a top-level (or static) function — the FCM plugin runs it in a
/// separate background isolate when a data message arrives while the app is
/// backgrounded/terminated, so it can't close over any app state. A
/// `notification` payload (which this service always sends, see
/// pushNotifications.js on the backend) is displayed by the OS itself in
/// this state without any app code running at all; this handler only exists
/// so `data`-only messages would still be handled if that ever changes.
@pragma('vm:entry-point')
Future<void> gosureBackgroundMessageHandler(RemoteMessage message) async {
  AppLogger.i('PushNotification', 'Background message: ${message.messageId}');
}

/// WhatsApp-style push notifications for the Business app: a new customer
/// message (or agent activity) buzzes the phone when the relevant
/// conversation isn't already open (server-side presence check — see
/// presence.js on the backend; nothing here needs to report "I'm viewing
/// this", the existing SSE connection already is that signal).
class PushNotificationService {
  PushNotificationService._();
  static final _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  static final _sessionStorage = SessionStorage();
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;
  String? _lastKnownToken;

  static const _androidChannel = AndroidNotificationChannel(
    'gosure_business_messages',
    'Business messages',
    description: 'New messages on conversations you\'re handling',
    importance: Importance.high,
  );

  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      // Guards against any future regeneration leaving this stale/missing —
      // every other feature in this app must keep working regardless.
      AppLogger.e('PushNotification', 'Firebase.initializeApp failed — push notifications disabled', e, st);
      return;
    }
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(gosureBackgroundMessageHandler);

    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) => _openFromPayload(response.payload),
    );

    // Foreground: FCM never shows a system notification on its own while the
    // app is in the foreground (by design, on both platforms) — that's what
    // flutter_local_notifications here is for, so a message that arrives
    // while the app is open but on a *different* screen still buzzes, the
    // same way the one that arrives while backgrounded does via the OS.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(_androidChannel.id, _androidChannel.name,
              channelDescription: _androidChannel.description, importance: Importance.high, priority: Priority.high),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) => _openFromData(message.data));
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openFromData(initialMessage.data);

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      AppLogger.i('PushNotification', 'FCM token refreshed');
      _registerToken(token);
    });
  }

  void _openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _openFromData((jsonDecode(payload) as Map).cast<String, dynamic>());
    } catch (e) {
      AppLogger.w('PushNotification', 'Could not parse notification payload: $e');
    }
  }

  Future<void> _openFromData(Map<String, dynamic> data) async {
    final conversationId = data['conversationId'] as String?;
    AppLogger.i('PushNotification', 'Opening from notification, conversationId=$conversationId');

    final businessId = await _sessionStorage.readBusinessId();
    if (conversationId != null && conversationId.isNotEmpty && businessId != null && businessId.isNotEmpty) {
      try {
        final convo = await BusinessChatService.fetchConversation(conversationId, businessId);
        final nav = navigatorKey.currentState;
        if (convo != null && nav != null) {
          nav.pushNamed(AppRoutes.businessConversations);
          nav.push(MaterialPageRoute(
            builder: (_) => ConversationDetailView(conversation: convo, businessId: businessId),
          ));
          return;
        }
      } catch (e, st) {
        AppLogger.e('PushNotification', 'Could not fetch conversation for deep link', e, st);
      }
    }
    // Fallback: couldn't resolve the specific conversation (not found, no
    // businessId yet, or the fetch failed) — still land somewhere real and
    // useful rather than nowhere.
    navigatorKey.currentState?.pushNamed(AppRoutes.businessConversations);
  }

  /// Call once, right after a successful login/session restore — this app's
  /// own businessId (already resolved and cached, see
  /// business_lookup_service.dart) is what lets the backend notify "this
  /// business" for an incoming customer message without a fresh ownership
  /// lookup on every send.
  Future<void> registerForCurrentUser() async {
    if (_initializing != null) await _initializing;
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (e, st) {
      AppLogger.e('PushNotification', 'Could not get/register FCM token', e, st);
    }
  }

  // Gosure routes on this backend expect X-Tenant-Id/X-User-Id/X-Gosure-Token,
  // not a bearer-only header — mirrors BusinessChatService._headers() exactly
  // (X-Gosure-Token is actually the session's access token). This service used
  // to hand-roll its own headers with only Authorization: Bearer, which the
  // backend's NO_AUTH bridge rejects outright with a 403 ("A valid X-Tenant-Id
  // header is required") since it never even reaches real auth — confirmed
  // live, this is exactly why push registration/unregistration were failing
  // silently (caught, logged, swallowed) for every signed-in user, business
  // and broker alike.
  Future<Map<String, String>> _gosureHeaders() async {
    final userId = await _sessionStorage.readUserId();
    final token = await _sessionStorage.readAccessToken();
    return {
      'Content-Type': 'application/json',
      'X-Tenant-Id': ServerUrls.tenant,
      if (userId != null) 'X-User-Id': userId,
      if (token != null) 'X-Gosure-Token': token,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _registerToken(String token) async {
    _lastKnownToken = token;
    final businessId = await _sessionStorage.readBusinessId();
    final accessToken = await _sessionStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    // This same service/class is shared by both sign-in modes (broker/business
    // dual-mode login) — 'app' was hardcoded to 'business' regardless of which
    // role is actually signed in. The businessId field below already holds the
    // right id either way (see business_lookup_service.dart), so notification
    // delivery itself was never broken by this, but the stored PushToken
    // record mislabeled every broker's device as a business device — wrong
    // for any future admin/debug view keyed on 'app', so labeled correctly now.
    final roleName = (await _sessionStorage.readRoleName())?.trim().toLowerCase() ?? '';
    final isBroker = roleName.contains('broker');
    try {
      final res = await http.post(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/push/register'),
        headers: await _gosureHeaders(),
        body: jsonEncode({
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'app': isBroker ? 'broker' : 'business',
          if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
        }),
      );
      AppLogger.i('PushNotification', 'Register push token -> ${res.statusCode}');
    } catch (e, st) {
      AppLogger.e('PushNotification', 'Failed to register push token', e, st);
    }
  }

  /// Call on sign-out — a shared/reset device must stop receiving the
  /// signed-out account's notifications.
  Future<void> unregister() async {
    final token = _lastKnownToken;
    if (token == null) return;
    final accessToken = await _sessionStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    try {
      await http.post(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.gosureConvos}/push/unregister'),
        headers: await _gosureHeaders(),
        body: jsonEncode({'token': token}),
      );
    } catch (e, st) {
      AppLogger.e('PushNotification', 'Failed to unregister push token', e, st);
    } finally {
      _lastKnownToken = null;
    }
  }
}
