import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/models/app_user.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/token_store.dart';

enum SessionStatus { loading, signedOut, signedIn, error }

class SessionState {
  const SessionState(this.status, {this.user, this.error});

  const SessionState.loading() : this(SessionStatus.loading);
  const SessionState.signedOut() : this(SessionStatus.signedOut);

  final SessionStatus status;

  /// Present when [status] is signedIn. The role is a UI hint only; the server
  /// re-checks the real role on every request.
  final AppUser? user;

  /// Present when [status] is error (e.g. offline while restoring a session).
  final Object? error;
}

/// Owns the session lifecycle:
///   restore()   - on launch: token from secure storage -> GET /api/auth/me
///   signedIn()  - after OTP verification (token already issued by the server)
///   signOut()   - POST /api/auth/logout (revokes it server-side), wipe the token
///   expire()    - the server said 401: wipe the token and show the login screen
/// While signed in, the profile (and thus role) is re-read every 5 minutes so a
/// role change or deactivation made by an admin shows up without a restart.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._api, this._tokens) : super(const SessionState.loading());

  final ApiClient _api;
  final TokenStore _tokens;
  Timer? _timer;

  static const profileRefresh = Duration(minutes: 5);

  Future<void> restore() async {
    state = const SessionState.loading();
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      state = const SessionState.signedOut();
      return;
    }
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final json = await _api.get('/api/auth/me');
      final user = AppUser.fromSession(json['user'] as Map<String, dynamic>);
      state = SessionState(SessionStatus.signedIn, user: user);
      _startTimer();
    } catch (e) {
      final ex = AppException.from(e);
      if (ex.messageKey == 'err_session_expired') {
        await expire();
      } else if (state.status != SessionStatus.signedIn) {
        // Offline at launch: keep the token and let the user retry.
        state = SessionState(SessionStatus.error, error: ex);
      } // else: transient failure during a refresh - keep the current profile
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(profileRefresh, (_) {
      if (state.status == SessionStatus.signedIn) _loadProfile();
    });
  }

  /// Persists the token (encrypted storage) and enters the signed-in state.
  Future<void> signedIn(String token, AppUser user) async {
    await _tokens.write(token);
    state = SessionState(SessionStatus.signedIn, user: user);
    _startTimer();
  }

  /// Ends the session everywhere: server-side revocation first (best effort),
  /// then the local token is wiped regardless of the network result.
  Future<void> signOut() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // offline or already expired: the local wipe below still signs the user out
    }
    await expire();
  }

  Future<void> expire() async {
    _timer?.cancel();
    await _tokens.clear();
    if (mounted) state = const SessionState.signedOut();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
