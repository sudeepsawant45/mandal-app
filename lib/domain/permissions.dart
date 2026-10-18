import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// Role policy. This mirrors backend/src/permissions.js (the real enforcement); the UI
/// uses it only to hide or disable controls, never as the security boundary.
///
/// Policy decisions that the project brief leaves open (documented in README):
///  * Households are managed by admins only (brief: admin "add, edit, view households").
///  * Committee members may create visarjan groups and sponsors, because
///    entries cannot be recorded without them.
///  * Committee members may edit / soft-delete only entries they created and
///    only within [AppConstants.committeeEditWindow].
///  * Viewers can view reports on screen but cannot export or share files.
class Permissions {
  Permissions._();

  static bool canViewData(AppRole r) =>
      r == AppRole.admin || r == AppRole.committee || r == AppRole.viewer;

  static bool canAddEntry(AppRole r) => r == AppRole.admin || r == AppRole.committee;

  static bool canManageHouseholds(AppRole r) => r == AppRole.admin;

  static bool canManageGroupsAndSponsors(AppRole r) =>
      r == AppRole.admin || r == AppRole.committee;

  static bool canManageUsers(AppRole r) => r == AppRole.admin;

  static bool canConfigureSettings(AppRole r) => r == AppRole.admin;

  static bool canExportReports(AppRole r) =>
      r == AppRole.admin || r == AppRole.committee;

  static bool canViewAudit(AppRole r) =>
      r == AppRole.admin || r == AppRole.committee;

  static bool canRestoreEntries(AppRole r) => r == AppRole.admin;

  static bool isReadOnly(AppRole r) => r == AppRole.viewer;

  /// Whether [role] / [uid] may edit or soft-delete [entry] at [now].
  static bool canModifyEntry({
    required AppRole role,
    required String uid,
    required LedgerEntry entry,
    required DateTime now,
  }) {
    if (role == AppRole.admin) return true;
    if (role == AppRole.committee) {
      return !entry.isDeleted &&
          entry.createdBy == uid &&
          now.difference(entry.createdAt) < AppConstants.committeeEditWindow;
    }
    return false;
  }
}
