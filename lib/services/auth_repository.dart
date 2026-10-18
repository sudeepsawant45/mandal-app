import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/models/app_user.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/session_controller.dart';

/// Email-OTP sign-in against the Node.js API. There is no Firebase Auth.
///
/// 1. [requestCode]      - the server emails a 6-digit code (only to approved
///                         members; the reply is identical for everyone else).
/// 2. [verifyAndSignIn]  - the server checks the code and returns a random
///                         session token; it is kept in Android secure storage
///                         and sent as a Bearer header. Only the server decides
///                         whether it is valid (expiry, logout, deactivation).
/// There is no registration and no password: accounts are created by an admin.
class AuthRepository {
  AuthRepository(this._api, this._session);

  final ApiClient _api;
  final SessionController _session;

  bool get isConfigured => _api.isConfigured;

  Future<void> requestCode(String email) async {
    await _api.post('/api/auth/request-otp', body: {'email': email.trim()}, auth: false);
  }

  Future<void> verifyAndSignIn(String email, String code) async {
    final json = await _api.post(
      '/api/auth/verify-otp',
      body: {'email': email.trim(), 'code': code.trim()},
      auth: false,
    );
    final token = json['token'];
    final user = json['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const AppException('err_generic', 'bad response');
    }
    await _session.signedIn(token, AppUser.fromSession(user));
  }

  Future<void> signOut() => _session.signOut();
}
