import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/app_user.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/services/household_repository.dart';
import 'package:ganpati_mandal/services/ledger_repository.dart';
import 'package:ganpati_mandal/services/polling.dart';
import 'package:ganpati_mandal/services/user_repository.dart';

import 'helpers/factories.dart';
import 'helpers/fake_api.dart';

const admin = Actor(uid: 'admin1', name: 'Admin', role: AppRole.admin);
const committee = Actor(uid: 'u1', name: 'Asha', role: AppRole.committee);
const viewer = Actor(uid: 'v1', name: 'View', role: AppRole.viewer);

Map<String, dynamic> serverEntry(String id, {int modifiedAt = 100, bool deleted = false}) => {
      'id': id,
      'fund': 'common_mandal',
      'type': 'income',
      'amountPaise': 50000,
      'date': '2026-09-10',
      'description': 'Gift',
      'category': 'general_income',
      'createdBy': 'u1',
      'createdByName': 'Asha',
      'createdAt': 90,
      'modifiedAt': modifiedAt,
      'isDeleted': deleted,
    };

void main() {
  group('LedgerEntry <-> API', () {
    test('toApiBody sends only user-editable fields (server rejects unknown keys)', () {
      final e = commonIncome('c1', 1000);
      final body = e.toApiBody();
      expect(body['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      for (final forbidden in [
        'createdBy', 'createdByName', 'createdAt', 'modifiedAt', 'isDeleted',
        'updatedBy', 'deletedBy', 'householdName', 'visarjanGroupName', 'sponsorName',
      ]) {
        expect(body.containsKey(forbidden), isFalse, reason: forbidden);
      }
      expect(e.toApiBody(includeId: false).containsKey('id'), isFalse);
    });

    test('fromMap reads epoch-ms timestamps and YYYY-MM-DD dates', () {
      final e = LedgerEntry.fromMap('x1', serverEntry('x1'));
      expect(e.date, DateTime(2026, 9, 10));
      expect(e.createdAt, DateTime.fromMillisecondsSinceEpoch(90));
      expect(e.isDeleted, isFalse);
    });

    test('readDate handles ints, ISO strings, plain dates and junk', () {
      expect(readDate(1000), DateTime.fromMillisecondsSinceEpoch(1000));
      expect(readDate('2026-09-10'), DateTime(2026, 9, 10));
      expect(readDate('2026-09-10T10:00:00Z'), isNotNull);
      expect(readDate(null), isNull);
      expect(readDate(<String, dynamic>{}), isNull);
      expect(apiDate(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('LedgerRepository', () {
    test('first sync downloads everything; later syncs ask only for changes', () async {
      var round = 0;
      final api = FakeApi((c) {
        round++;
        return round == 1
            ? ok({'entries': [serverEntry('a', modifiedAt: 100), serverEntry('b', modifiedAt: 200)], 'nextSince': null})
            : ok({'entries': [serverEntry('b', modifiedAt: 300, deleted: true)], 'nextSince': null});
      }, token: 't');
      final repo = LedgerRepository(api.client);
      expect((await repo.sync()).length, 2);
      final second = await repo.sync();
      expect(api.calls[0].url.queryParameters['since'], '0');
      expect(api.calls[1].url.queryParameters['since'], '200');
      expect(second.length, 2);
      expect(second.firstWhere((e) => e.id == 'b').isDeleted, isTrue); // deletions propagate
    });

    test('our own save does NOT advance the sync cursor (others\' earlier changes are not skipped)', () async {
      final api = FakeApi((c) {
        if (c.method == 'POST') return ok({'created': true, 'entry': serverEntry('new', modifiedAt: 9999)}, 201);
        return ok({'entries': [], 'nextSince': null});
      }, token: 't');
      final repo = LedgerRepository(api.client);
      await repo.create(commonIncome('new-entry-id-0000000000000001', 1000), committee);
      await repo.sync();
      expect(api.calls.last.url.queryParameters['since'], '0');
    });

    test('create posts to /api/transactions and reports idempotent replays as false', () async {
      final api = FakeApi((c) => ok({'created': false, 'entry': serverEntry('dup')}), token: 't');
      final repo = LedgerRepository(api.client);
      final created = await repo.create(commonIncome('dup', 1000), committee);
      expect(created, isFalse);
      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.url.path, '/api/transactions');
    });

    test('a viewer is stopped before any request is made', () async {
      final api = FakeApi((c) => ok({}), token: 't');
      final repo = LedgerRepository(api.client);
      expect(() => repo.create(commonIncome('x', 1000), viewer), throwsA(isA<AppException>()));
      expect(api.calls, isEmpty);
    });

    test('an invalid entry is rejected locally; a server rejection surfaces as an AppException', () async {
      final api = FakeApi((c) => errJson(403, 'forbidden'), token: 't');
      final repo = LedgerRepository(api.client);
      expect(() => repo.create(commonIncome('bad', 0), committee), throwsA(isA<AppException>()));
      expect(api.calls, isEmpty);
      try {
        await repo.create(commonIncome('ok', 1000), committee);
        fail('should throw');
      } on AppException catch (e) {
        expect(e.messageKey, 'err_permission');
      }
    });

    test('softDelete and restore use their own endpoints; restore is admin-only', () async {
      final api = FakeApi((c) => ok({'entry': serverEntry('c1', deleted: c.url.path.endsWith('/delete'))}), token: 't');
      final repo = LedgerRepository(api.client);
      final own = commonIncome('c1', 1000).copyWith(createdBy: 'u1', createdAt: DateTime.now());
      await repo.softDelete(own, committee);
      expect(api.calls.last.url.path, '/api/transactions/c1/delete');
      expect(() => repo.restore(own, committee), throwsA(isA<AppException>()));
      await repo.restore(own, admin);
      expect(api.calls.last.url.path, '/api/transactions/c1/restore');
    });
  });

  group('UserRepository / HouseholdRepository', () {
    test('an admin cannot change their own role or status', () async {
      final api = FakeApi((c) => ok({}), token: 't');
      final repo = UserRepository(api.client);
      final self = AppUser(uid: 'admin1', email: 'a@x.com', displayName: 'A', role: AppRole.admin, active: true);
      expect(() => repo.setRole(target: self, newRole: AppRole.viewer, actor: admin), throwsA(isA<AppException>()));
      expect(() => repo.setActive(target: self, active: false, actor: admin), throwsA(isA<AppException>()));
      expect(api.calls, isEmpty);
    });

    test('only admins manage members; role change goes to PUT /api/users/:id', () async {
      final api = FakeApi((c) => ok({}), token: 't');
      final repo = UserRepository(api.client);
      final other = AppUser(uid: 'u9', email: 'o@x.com', displayName: 'O', role: AppRole.viewer, active: true);
      expect(
        () => repo.createMember(email: 'n@x.com', displayName: 'N', role: AppRole.admin, actor: committee),
        throwsA(isA<AppException>()),
      );
      await repo.setRole(target: other, newRole: AppRole.committee, actor: admin);
      expect(api.calls.single.method, 'PUT');
      expect(api.calls.single.url.path, '/api/users/u9');
      expect(api.calls.single.json, {'role': 'committee'});
    });

    test('households: admin only; archive via PUT with active flag', () async {
      final api = FakeApi((c) => ok({'item': {'id': 'h9'}}, 201), token: 't');
      final repo = HouseholdRepository(api.client);
      expect(() => repo.add(name: 'X', actor: committee), throwsA(isA<AppException>()));
      expect(await repo.add(name: ' Patil ', actor: admin), 'h9');
      expect(api.calls.single.json, {'name': 'Patil', 'notes': null});
    });
  });

  group('pollStream', () {
    test('emits immediately, then on every refresh; later failures keep the last data', () async {
      var n = 0;
      final refresh = StreamController<void>.broadcast();
      final out = <int>[];
      final errors = <Object>[];
      final sub = pollStream<int>(
        load: () async {
          n++;
          if (n == 3) throw StateError('network blip');
          return n;
        },
        every: const Duration(hours: 1),
        refreshes: refresh.stream,
      ).listen(out.add, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      refresh.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      refresh.add(null); // this poll fails: no error event, no new value
      await Future<void>.delayed(const Duration(milliseconds: 20));
      refresh.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(out, [1, 2, 4]);
      expect(errors, isEmpty);
      await sub.cancel();
    });

    test('a failing FIRST load is reported', () async {
      final errors = <Object>[];
      final sub = pollStream<int>(load: () async => throw StateError('x'), every: const Duration(hours: 1))
          .listen((_) {}, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(errors, hasLength(1));
      await sub.cancel();
    });
  });
}
