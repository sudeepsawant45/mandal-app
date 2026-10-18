import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/services/token_store.dart';

/// Raw HTTP result handed back by a transport.
class ApiResponse {
  const ApiResponse(this.status, this.json);

  final int status;
  final Map<String, dynamic>? json;
}

typedef ApiTransport = Future<ApiResponse> Function(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
);

/// The ONLY way the app talks to the mandal's data: HTTPS calls to the Node.js
/// API with `Authorization: Bearer <session token>`. The client has no
/// Firebase code, no database credentials and no SMTP secrets. The role it
/// shows in the UI is a hint; the server decides on every call.
///
/// The base URL is not a secret; it is injected at build time:
///   `--dart-define=API_BASE_URL=https://YOUR-PROJECT.vercel.app`
class ApiClient {
  ApiClient({
    required TokenStore tokens,
    String? baseUrl,
    ApiTransport? transport,
    this.onUnauthorized,
    bool? allowInsecureHttp,
  })  : _tokens = tokens,
        _allowHttp = allowInsecureHttp ?? kDebugMode,
        _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL'),
        _transport = transport ?? _defaultTransport;

  final TokenStore _tokens;
  final String _baseUrl;
  final ApiTransport _transport;

  /// Plain http is accepted only when this is true; it defaults to debug builds
  /// (e.g. an emulator talking to a local server). Release builds are always https-only.
  final bool _allowHttp;

  /// Called when the server rejects the session (401 on a protected call).
  final void Function()? onUnauthorized;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Uri _url(String path, Map<String, String>? query) {
    if (!isConfigured) throw const AppException('err_otp_not_configured');
    final trimmed = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final base = Uri.parse(trimmed);
    // Release builds only talk to the backend over TLS.
    if (base.scheme != 'https' && !(_allowHttp && base.scheme == 'http')) {
      throw const AppException('err_otp_not_configured', 'https required');
    }
    return base.replace(
      path: '${base.path}$path',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  /// Sends one request and returns the decoded `{ok: true, ...}` body.
  /// Every failure is thrown as an [AppException] with a localisable key.
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final url = _url(path, query);
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (auth) {
      final token = await _tokens.read();
      if (token == null || token.isEmpty) {
        onUnauthorized?.call();
        throw const AppException('err_session_expired');
      }
      headers['authorization'] = 'Bearer $token';
    }

    final ApiResponse res;
    try {
      res = await _transport(method, url, headers, body == null ? null : jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException('err_network', 'timeout');
    } on SocketException {
      throw const AppException('err_network');
    } on HandshakeException {
      throw const AppException('err_network', 'tls');
    } catch (e) {
      throw AppException('err_generic', e.runtimeType.toString());
    }

    final json = res.json;
    if (res.status >= 200 && res.status < 300 && json != null && json['ok'] == true) {
      return json;
    }
    if (res.status == 401 && auth) onUnauthorized?.call();
    throw mapError(res.status, json, auth: auth);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, bool auth = true}) =>
      send('POST', path, body: body ?? const {}, auth: auth);

  Future<Map<String, dynamic>> put(String path, {required Map<String, dynamic> body}) =>
      send('PUT', path, body: body);

  /// Maps an API failure to a user-presentable [AppException]. Public so it is testable.
  static AppException mapError(int status, Map<String, dynamic>? json, {required bool auth}) {
    final code = json?['code'];
    final detail = json?['detail'];
    switch (status) {
      case 400:
        if (!auth) return const AppException('err_otp_bad_request');
        if (code == 'invalid_entry' || code == 'inactive_reference') {
          return AppException('err_invalid_entry', detail is String ? detail : null);
        }
        if (code == 'cannot_change_self') return const AppException('err_cannot_change_own_role');
        return AppException('err_invalid_entry', detail is String ? detail : null);
      case 401:
        return AppException(auth ? 'err_session_expired' : 'err_otp_invalid');
      case 403:
        return const AppException('err_permission');
      case 404:
        return const AppException('err_generic', 'not_found');
      case 409:
        if (code == 'duplicate_name') return const AppException('v_duplicate_name');
        if (code == 'email_in_use') return const AppException('err_email_in_use');
        return const AppException('err_generic', 'conflict');
      case 429:
        final wait = json?['retryAfterSec'];
        return AppException('err_otp_rate_limited', wait is int ? '${wait}s' : null);
      case 503:
        return AppException(
          code == 'email_unavailable' ? 'err_otp_email_unavailable' : 'err_service_unavailable',
        );
      default:
        return AppException('err_service_unavailable', '$status');
    }
  }

  static Future<ApiResponse> _defaultTransport(
    String method,
    Uri url,
    Map<String, String> headers,
    String? body,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl(method, url);
      headers.forEach(req.headers.set);
      if (body != null) req.add(utf8.encode(body));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}
      return ApiResponse(resp.statusCode, json);
    } finally {
      client.close(force: true);
    }
  }
}
