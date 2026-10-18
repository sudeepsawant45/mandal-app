import 'dart:async';

import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/app_user.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/polling.dart';

/// Member management via /api/users (Admin only, enforced by the server).
/// There is no self-registration: this is the only way an account comes to exist.
class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  Future<List<AppUser>> fetchAll() async {
    final json = await _api.get('/api/users');
    final list = [
      for (final raw in (json['users'] as List?) ?? const [])
        AppUser.fromMap((raw as Map<String, dynamic>)['id'] as String, raw),
    ];
    list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  Stream<List<AppUser>> watchAll() => pollStream<List<AppUser>>(
        load: fetchAll,
        every: const Duration(minutes: 2),
        refreshes: _changed.stream,
      );

  Future<void> createMember({
    required String email,
    required String displayName,
    required AppRole role,
    required Actor actor,
  }) async {
    if (!Permissions.canManageUsers(actor.role)) {
      throw const AppException('err_permission');
    }
    if (role == AppRole.pending) throw const AppException('err_generic', 'invalid role');
    try {
      await _api.post('/api/users', body: {
        'email': email.trim().toLowerCase(),
        'displayName': displayName.trim(),
        'role': role.value,
      });
      _changed.add(null);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deactivates / reactivates another member (never oneself). Deactivation
  /// also ends that member's live sessions on the server.
  Future<void> setActive({
    required AppUser target,
    required bool active,
    required Actor actor,
  }) =>
      _update(target, actor, {'active': active});

  /// Changes another member's role (never one's own). Takes effect on the
  /// member's very next request.
  Future<void> setRole({
    required AppUser target,
    required AppRole newRole,
    required Actor actor,
  }) =>
      _update(target, actor, {'role': newRole.value});

  Future<void> _update(AppUser target, Actor actor, Map<String, dynamic> body) async {
    if (!Permissions.canManageUsers(actor.role)) {
      throw const AppException('err_permission');
    }
    if (target.uid == actor.uid) {
      throw const AppException('err_cannot_change_own_role');
    }
    try {
      await _api.put('/api/users/${target.uid}', body: body);
      _changed.add(null);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
