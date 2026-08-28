import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthSession {
  final String accessToken;
  final String token;
  final User user;
  const AuthSession(
      {required this.accessToken, required this.token, required this.user});
}

class SessionStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _nameKey = 'auth_name';
  static const _usernameKey = 'auth_username';
  static const _roleNameKey = 'auth_role_name';
  static const _businessIdKey = 'gosure_business_id';
  static const _businessDataKey = 'gosure_business_data';
  static const _rememberedUsernameKeyBase = 'remembered_username';
  static const _rememberedPasswordKeyBase = 'remembered_password';

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> readUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> readRoleName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleNameKey);
  }

  Future<AuthSession?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    final name = prefs.getString(_nameKey);
    final username = prefs.getString(_usernameKey);
    final roleName = prefs.getString(_roleNameKey);
    if (accessToken == null ||
        token == null ||
        userId == null ||
        name == null ||
        username == null ||
        roleName == null) {
      return null;
    }
    return AuthSession(
      accessToken: accessToken,
      token: token,
      user:
          User(id: userId, name: name, username: username, roleName: roleName),
    );
  }

  Future<void> saveSession(
      {required String accessToken,
      required String token,
      required User user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_nameKey, user.name);
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_roleNameKey, user.roleName);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleNameKey);
  }

  String _rememberedUsernameKey(bool isBroker) => isBroker ? '${_rememberedUsernameKeyBase}_broker' : _rememberedUsernameKeyBase;
  String _rememberedPasswordKey(bool isBroker) => isBroker ? '${_rememberedPasswordKeyBase}_broker' : _rememberedPasswordKeyBase;

  Future<void> saveRememberedCredentials(
      {required String username, required String password, bool isBroker = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedUsernameKey(isBroker), username);
    await prefs.setString(_rememberedPasswordKey(isBroker), password);
  }

  Future<({String username, String password})?> readRememberedCredentials({bool isBroker = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_rememberedUsernameKey(isBroker));
    final password = prefs.getString(_rememberedPasswordKey(isBroker));
    if (username == null || password == null) return null;
    return (username: username, password: password);
  }

  Future<void> clearRememberedCredentials({bool isBroker = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedUsernameKey(isBroker));
    await prefs.remove(_rememberedPasswordKey(isBroker));
  }

  // Cache for the businessId auto-resolved from the signed-in user's account (see
  // BusinessConversationsViewModel._resolveMyBusinessId) — there is no manual-entry
  // fallback, so this stays empty until that resolution succeeds.
  Future<String?> readBusinessId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_businessIdKey);
  }

  Future<void> saveBusinessId(String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessIdKey, businessId);
  }

  Future<Map<String, dynamic>?> readBusinessData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_businessDataKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveBusinessData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessDataKey, jsonEncode(data));
  }

  // How many messages this device had already seen in a conversation as of the last
  // time it was opened — compared against the list endpoint's live messageCount to
  // show a "N new" badge, the same way an unread-count badge works in any chat app.
  static const _readCountPrefix = 'gosure_read_count_';

  Future<int> readLastSeenCount(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_readCountPrefix$conversationId') ?? 0;
  }

  Future<void> saveLastSeenCount(String conversationId, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_readCountPrefix$conversationId', count);
  }

  // Business/conversation state is scoped to whichever user resolved or entered it — clear it
  // on logout so a different user signing in on the same device doesn't inherit the previous
  // user's business ID or see its conversations already marked as read.
  Future<void> clearBusinessData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_businessIdKey);
    await prefs.remove(_businessDataKey);
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_readCountPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
