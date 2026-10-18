import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session token lives between app launches.
///
/// The token is a bearer credential, so production uses Android's encrypted
/// storage ([SecureTokenStore]); it is never written to SharedPreferences,
/// plain files or logs. The server stores only a hash of it.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _key = 'mandal_session_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null; // unreadable keystore entry -> behave as signed out
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // nothing more we can do; the server-side session is revoked separately
    }
  }
}

/// In-memory store for tests only.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}
