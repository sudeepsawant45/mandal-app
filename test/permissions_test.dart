import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

import 'helpers/factories.dart';

void main() {
  group('role capabilities', () {
    test('admin can do everything', () {
      const r = AppRole.admin;
      expect(Permissions.canViewData(r), isTrue);
      expect(Permissions.canAddEntry(r), isTrue);
      expect(Permissions.canManageHouseholds(r), isTrue);
      expect(Permissions.canManageGroupsAndSponsors(r), isTrue);
      expect(Permissions.canManageUsers(r), isTrue);
      expect(Permissions.canConfigureSettings(r), isTrue);
      expect(Permissions.canExportReports(r), isTrue);
      expect(Permissions.canViewAudit(r), isTrue);
      expect(Permissions.canRestoreEntries(r), isTrue);
      expect(Permissions.isReadOnly(r), isFalse);
    });

    test('committee member adds entries and exports reports, but cannot administer', () {
      const r = AppRole.committee;
      expect(Permissions.canViewData(r), isTrue);
      expect(Permissions.canAddEntry(r), isTrue);
      expect(Permissions.canExportReports(r), isTrue);
      expect(Permissions.canManageGroupsAndSponsors(r), isTrue);
      expect(Permissions.canManageHouseholds(r), isFalse);
      expect(Permissions.canManageUsers(r), isFalse);
      expect(Permissions.canConfigureSettings(r), isFalse);
      expect(Permissions.canRestoreEntries(r), isFalse);
    });

    test('viewer is strictly read-only', () {
      const r = AppRole.viewer;
      expect(Permissions.canViewData(r), isTrue);
      expect(Permissions.isReadOnly(r), isTrue);
      expect(Permissions.canAddEntry(r), isFalse);
      expect(Permissions.canManageHouseholds(r), isFalse);
      expect(Permissions.canManageGroupsAndSponsors(r), isFalse);
      expect(Permissions.canManageUsers(r), isFalse);
      expect(Permissions.canConfigureSettings(r), isFalse);
      expect(Permissions.canExportReports(r), isFalse);
      expect(Permissions.canRestoreEntries(r), isFalse);
    });

    test('pending users have no access at all', () {
      const r = AppRole.pending;
      expect(Permissions.canViewData(r), isFalse);
      expect(Permissions.canAddEntry(r), isFalse);
      expect(Permissions.canManageUsers(r), isFalse);
      expect(Permissions.canExportReports(r), isFalse);
      expect(Permissions.canViewAudit(r), isFalse);
    });

    test('unknown stored roles fail closed to pending', () {
      expect(AppRole.fromValue(null), AppRole.pending);
      expect(AppRole.fromValue('superuser'), AppRole.pending);
      expect(AppRole.fromValue('admin'), AppRole.admin);
    });
  });

  group('editing / deleting entries', () {
    final own = commonIncome('c1', 1000).copyWith(createdBy: 'u1', createdAt: kCreated);

    test('admin may modify any entry, including old and deleted ones', () {
      final old = own.copyWith(createdAt: DateTime(2020, 1, 1), createdBy: 'someone');
      expect(
        Permissions.canModifyEntry(role: AppRole.admin, uid: 'admin1', entry: old, now: kNow),
        isTrue,
      );
      expect(
        Permissions.canModifyEntry(
          role: AppRole.admin,
          uid: 'admin1',
          entry: own.copyWith(isDeleted: true),
          now: kNow,
        ),
        isTrue,
      );
    });

    test('committee may modify their own recent entry', () {
      expect(
        Permissions.canModifyEntry(role: AppRole.committee, uid: 'u1', entry: own, now: kNow),
        isTrue,
      );
    });

    test('committee may not modify someone else\'s entry', () {
      expect(
        Permissions.canModifyEntry(role: AppRole.committee, uid: 'u2', entry: own, now: kNow),
        isFalse,
      );
    });

    test('committee edit window ends after 7 days', () {
      final justInside = own.copyWith(
        createdAt: kNow.subtract(AppConstants.committeeEditWindow - const Duration(minutes: 1)),
      );
      final justOutside = own.copyWith(
        createdAt: kNow.subtract(AppConstants.committeeEditWindow),
      );
      expect(
        Permissions.canModifyEntry(role: AppRole.committee, uid: 'u1', entry: justInside, now: kNow),
        isTrue,
      );
      expect(
        Permissions.canModifyEntry(role: AppRole.committee, uid: 'u1', entry: justOutside, now: kNow),
        isFalse,
      );
    });

    test('committee cannot touch a deleted entry', () {
      expect(
        Permissions.canModifyEntry(
          role: AppRole.committee,
          uid: 'u1',
          entry: own.copyWith(isDeleted: true),
          now: kNow,
        ),
        isFalse,
      );
    });

    test('viewer and pending users can never modify entries', () {
      for (final role in [AppRole.viewer, AppRole.pending]) {
        expect(
          Permissions.canModifyEntry(role: role, uid: 'u1', entry: own, now: kNow),
          isFalse,
          reason: role.value,
        );
      }
    });
  });
}
