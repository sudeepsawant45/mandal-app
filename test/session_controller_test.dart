import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/app_user.dart';
import 'package:ganpati_mandal/services/auth_repository.dart';
import 'package:ganpati_mandal/services/session_controller.dart';

import 'helpers/fake_api.dart';

const meJson = {
  'id': 'u1',
  'email': 'a@example.com',
  'displayName': 'Asha',
  'role': 'committee',
};

void main() {
  test('restore with no saved token -> signed out, no network call', () async {
    final api = FakeApi((c) => ok({}));
    final s = SessionController(api.client, api.tokens);
    await s.restore();
    expect(s.state.status, SessionStatus.signedOut);
    expect(api.calls, isEmpty);
  });

  test('restore with a valid token asks the server who we are', () async {
    final api = FakeApi((c) => ok({'user': meJson}), token: 'T');
    final s = SessionController(api.client, api.tokens);
    await s.restore();
    expect(s.state.status, SessionStatus.signedIn);
    expect(s.state.user!.role, AppRole.committee);
    expect(api.calls.single.url.path, '/api/auth/me');
    s.dispose();
  });

  test('a rejected token (401) signs out and wipes the stored token', () async {
    late SessionController s;
    final api = FakeApi((c) => errJson(401, 'unauthorized'), token: 'T', onUnauthorized: () => s.expire());
    s = SessionController(api.client, api.tokens);
    await s.restore();
    expect(s.state.status, SessionStatus.signedOut);
    expect(await api.tokens.read(), isNull);
  });

  test('offline at launch keeps the token and shows a retryable error', () async {
    final api = FakeApi((c) => throw const AppException('err_network'), token: 'T');
    final s = SessionController(api.client, api.tokens);
    await s.restore();
    expect(s.state.status, SessionStatus.error);
    expect(await api.tokens.read(), 'T');
  });

  test('verifyAndSignIn stores the token and enters signed-in state', () async {
    final api = FakeApi((c) {
      expect(c.url.path, '/api/auth/verify-otp');
      expect(c.headers.containsKey('authorization'), isFalse);
      expect(c.json, {'email': 'a@example.com', 'code': '123456'});
      return ok({'token': 'NEWTOKEN', 'expiresAtMs': 1, 'user': meJson});
    });
    final s = SessionController(api.client, api.tokens);
    await AuthRepository(api.client, s).verifyAndSignIn(' a@example.com ', '123456 ');
    expect(s.state.status, SessionStatus.signedIn);
    expect(await api.tokens.read(), 'NEWTOKEN');
    s.dispose();
  });

  test('a wrong code leaves the user signed out with err_otp_invalid', () async {
    final api = FakeApi((c) => errJson(401, 'invalid_or_expired'));
    final s = SessionController(api.client, api.tokens);
    await s.restore();
    try {
      await AuthRepository(api.client, s).verifyAndSignIn('a@example.com', '000000');
      fail('should throw');
    } on AppException catch (e) {
      expect(e.messageKey, 'err_otp_invalid');
    }
    expect(s.state.status, SessionStatus.signedOut);
    expect(await api.tokens.read(), isNull);
  });

  test('signOut revokes on the server and wipes the token', () async {
    final api = FakeApi((c) => ok({'user': meJson}), token: 'T');
    final s = SessionController(api.client, api.tokens);
    await s.restore();
    await s.signOut();
    expect(api.calls.last.url.path, '/api/auth/logout');
    expect(api.calls.last.method, 'POST');
    expect(s.state.status, SessionStatus.signedOut);
    expect(await api.tokens.read(), isNull);
  });

  test('signOut still signs out locally when the network call fails', () async {
    final api = FakeApi((c) {
      if (c.url.path.endsWith('/logout')) throw const AppException('err_network');
      return ok({'user': meJson});
    }, token: 'T');
    final s = SessionController(api.client, api.tokens);
    await s.restore();
    await s.signOut();
    expect(s.state.status, SessionStatus.signedOut);
    expect(await api.tokens.read(), isNull);
  });

  test('AppUser.fromSession is approved by construction; unknown roles still fail closed', () {
    expect(AppUser.fromSession(meJson).isApproved, isTrue);
    expect(AppUser.fromSession({...meJson, 'role': 'superuser'}).isApproved, isFalse);
  });
}
