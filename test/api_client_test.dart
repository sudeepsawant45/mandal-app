import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/token_store.dart';

import 'helpers/fake_api.dart';

Future<void> expectKey(Future<Object?> Function() f, String key, [String? detail]) async {
  try {
    await f();
    fail('expected AppException($key)');
  } on AppException catch (e) {
    expect(e.messageKey, key);
    if (detail != null) expect(e.detail, detail);
  }
}

void main() {
  test('protected calls carry the Bearer token; auth calls carry none', () async {
    final api = FakeApi((c) => ok({}), token: 'T0KEN');
    await api.client.get('/api/auth/me');
    await api.client.post('/api/auth/request-otp', body: {'email': 'a@x.com'}, auth: false);
    expect(api.calls[0].headers['authorization'], 'Bearer T0KEN');
    expect(api.calls[1].headers.containsKey('authorization'), isFalse);
    expect(api.calls[1].json, {'email': 'a@x.com'});
    expect(api.calls[0].url.toString(), 'https://api.example.test/api/auth/me');
  });

  test('query parameters are encoded', () async {
    final api = FakeApi((c) => ok({}), token: 't');
    await api.client.get('/api/transactions', query: {'since': '12'});
    expect(api.calls.single.url.queryParameters, {'since': '12'});
  });

  test('without a stored token a protected call fails locally with err_session_expired (no request sent)', () async {
    var expired = 0;
    final api = FakeApi((c) => ok({}), onUnauthorized: () => expired++);
    await expectKey(() => api.client.get('/api/users'), 'err_session_expired');
    expect(api.calls, isEmpty);
    expect(expired, 1);
  });

  test('401 on a protected call signals session expiry; on an auth call it means a bad code', () async {
    var expired = 0;
    final api = FakeApi((c) => errJson(401, 'unauthorized'), token: 't', onUnauthorized: () => expired++);
    await expectKey(() => api.client.get('/api/users'), 'err_session_expired');
    expect(expired, 1);
    await expectKey(
      () => api.client.post('/api/auth/verify-otp', body: {'email': 'a', 'code': '1'}, auth: false),
      'err_otp_invalid',
    );
    expect(expired, 1); // an invalid code must not look like a session expiry
  });

  test('status codes map to localisable keys', () {
    AppException map(int s, [Map<String, dynamic>? j, bool auth = true]) =>
        ApiClient.mapError(s, j, auth: auth);
    expect(map(403).messageKey, 'err_permission');
    expect(map(400, {'code': 'invalid_entry', 'detail': 'amount:v_amount_positive'}).messageKey, 'err_invalid_entry');
    expect(map(400, {'code': 'invalid_entry', 'detail': 'amount:v_amount_positive'}).detail, 'amount:v_amount_positive');
    expect(map(400, {'code': 'cannot_change_self'}).messageKey, 'err_cannot_change_own_role');
    expect(map(400, null, false).messageKey, 'err_otp_bad_request');
    expect(map(409, {'code': 'duplicate_name'}).messageKey, 'v_duplicate_name');
    expect(map(409, {'code': 'email_in_use'}).messageKey, 'err_email_in_use');
    expect(map(429, {'retryAfterSec': 42}).detail, '42s');
    expect(map(429, {'retryAfterSec': 42}).messageKey, 'err_otp_rate_limited');
    expect(map(503, {'code': 'email_unavailable'}).messageKey, 'err_otp_email_unavailable');
    expect(map(503, {'code': 'service_unavailable'}).messageKey, 'err_service_unavailable');
    expect(map(500).messageKey, 'err_service_unavailable');
  });

  test('a 2xx without ok:true is treated as a failure', () async {
    final api = FakeApi((c) => const ApiResponse(200, {'hello': 'world'}), token: 't');
    await expectKey(() => api.client.get('/api/x'), 'err_service_unavailable');
  });

  test('network problems map to err_network', () async {
    await expectKey(
      () => FakeApi((c) => throw const SocketException('down'), token: 't').client.get('/api/x'),
      'err_network',
    );
    await expectKey(
      () => FakeApi((c) => throw TimeoutException('slow'), token: 't').client.get('/api/x'),
      'err_network',
      'timeout',
    );
  });

  test('not configured / not https is refused before any request', () async {
    final api = FakeApi((c) => ok({}), token: 't', base: '');
    await expectKey(() => api.client.get('/api/x'), 'err_otp_not_configured');
    final plain = FakeApi((c) => ok({}), token: 't', base: 'http://api.example.test');
    await expectKey(() => plain.client.get('/api/x'), 'err_otp_not_configured', 'https required');
    expect(plain.calls, isEmpty);
  });

  test('plain http is accepted only when explicitly allowed (debug builds)', () async {
    final dev = FakeApi((c) => ok({}), token: 't', base: 'http://10.0.2.2:3000', allowInsecureHttp: true);
    await dev.client.get('/api/x');
    expect(dev.calls.single.url.toString(), 'http://10.0.2.2:3000/api/x');
  });

  test('MemoryTokenStore round-trips and clears', () async {
    final s = MemoryTokenStore();
    expect(await s.read(), isNull);
    await s.write('abc');
    expect(await s.read(), 'abc');
    await s.clear();
    expect(await s.read(), isNull);
  });
}
