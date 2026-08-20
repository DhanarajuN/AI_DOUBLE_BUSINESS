import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String baseUrl;
  final String? tenant;
  final http.Client _client;
  String? _accessToken;

  /// Fired whenever any call here gets a 401 — the token it was sent with is
  /// no longer valid server-side (expired, revoked), something no client
  /// code tracks proactively today. Left unhandled, this looked exactly like
  /// "that resource doesn't exist" to callers, with no way to recover except
  /// force-quitting and reopening the app. AuthRepository wires this to a
  /// real sign-out + return-to-login so a stale session recovers on its own.
  void Function()? onUnauthorized;

  ApiClient({required this.baseUrl, this.tenant, http.Client? client})
      : _client = client ?? http.Client();

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  Future<dynamic> get(String path, {Map<String, String>? query, Map<String, String>? headerOverrides}) {
    return _request('GET', path,
        () => _client.get(_uri(path, query), headers: _headers(headerOverrides)));
  }

  Future<dynamic> post(String path,
      {Object? body, Map<String, String>? query}) {
    return _request(
      'POST',
      path,
      () => _client.post(_uri(path, query),
          headers: _headers(), body: _encode(body)),
      body: body,
    );
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _request('PUT', path,
        () => _client.put(_uri(path), headers: _headers(), body: _encode(body)),
        body: body);
  }

  Future<dynamic> _request(
      String method, String path, Future<http.Response> Function() send,
      {Object? body}) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.i('ApiClient',
        '$method $path${body == null ? '' : ' body=${jsonEncode(redactJson(body))}'}');
    try {
      final response = await send();
      final result = _decode(response);
      AppLogger.i('ApiClient',
          '$method $path -> ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      AppLogger.e('ApiClient',
          '$method $path failed after ${stopwatch.elapsedMilliseconds}ms', e);
      rethrow;
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  String? _encode(Object? body) => body == null ? null : jsonEncode(body);

  Map<String, String> _headers([Map<String, String>? overrides]) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (tenant != null) 'X-Tenant': tenant!,
        if (_accessToken != null && _accessToken!.isNotEmpty)
          'Authorization': 'Bearer $_accessToken',
        if (overrides != null) ...overrides,
      };

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (status == 401) onUnauthorized?.call();
    if (status < 200 || status >= 300) {
      String? stringField(String key) =>
          body is Map && body[key] is String ? body[key] as String : null;
      String? listField(String key) => body is Map && body[key] is List
          ? (body[key] as List).map((e) => e.toString()).join(', ')
          : null;
      String? validationErrorsField() {
        if (body is! Map || body['validationErrors'] is! List) return null;
        final parts = <String>[];
        for (final entry in body['validationErrors'] as List) {
          if (entry is Map) {
            for (final field in entry.entries) {
              parts.add('${field.key}: ${field.value}');
            }
          } else if (entry != null) {
            parts.add(entry.toString());
          }
        }
        return parts.isEmpty ? null : parts.join('; ');
      }
      final serverMessage = stringField('msg') ??
          stringField('message') ??
          listField('messages') ??
          validationErrorsField();
      final reason = response.reasonPhrase;
      final message = (serverMessage != null && serverMessage.isNotEmpty)
          ? serverMessage
          : (reason != null && reason.isNotEmpty)
              ? reason
              : 'Request failed with status $status';
      throw ApiException(status, message);
    }
    return body;
  }

  void close() => _client.close();
}
