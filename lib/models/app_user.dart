import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

/// A member as served by the API (/api/users, /api/auth/me). Created by an
/// admin only. There are no passwords anywhere in this app.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.active,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final AppRole role;

  /// An inactive member has no access (rules + UI). Missing flag = inactive.
  final bool active;
  final DateTime? createdAt;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        email: (m['email'] as String?) ?? '',
        displayName: (m['displayName'] as String?) ?? '',
        role: AppRole.fromValue(m['role'] as String?),
        active: m['active'] == true,
        createdAt: readDate(m['createdAt']),
      );

  /// The signed-in user from /api/auth/me. The server only authenticates
  /// approved, active members, so the flag is true by construction.
  factory AppUser.fromSession(Map<String, dynamic> m) => AppUser(
        uid: (m['id'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        displayName: (m['displayName'] as String?) ?? '',
        role: AppRole.fromValue(m['role'] as String?),
        active: true,
      );

  /// Approved = real role (not pending) and active.
  bool get isApproved => active && role != AppRole.pending;

  String get label => displayName.isEmpty ? email : displayName;
}
