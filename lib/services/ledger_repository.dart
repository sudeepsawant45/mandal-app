import 'dart:async';

import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/domain/entry_validator.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/polling.dart';

/// Transactions via /api/transactions.
///
/// The server is the authority: it checks the session and the CURRENT role,
/// validates, rejects cross-fund references, stamps author/timestamps and
/// writes the audit line in the same transaction. The pre-checks here only
/// give faster feedback in the UI.
///
/// Reads are INCREMENTAL: the first call downloads everything, later polls ask
/// only for entries changed since the newest `modifiedAt` already held
/// (soft deletes arrive as `isDeleted: true`), which keeps Firestore reads low
/// on the free plan. One instance lives per signed-in session, so a different
/// user never sees a previous user's cache.
class LedgerRepository {
  LedgerRepository(this._api);

  final ApiClient _api;
  final Map<String, LedgerEntry> _cache = {};
  int _since = 0;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  static const pollInterval = Duration(seconds: 30);

  List<LedgerEntry> get _snapshot => List.unmodifiable(_cache.values);

  /// [fromSync] is true only for entries that arrived through [sync]. The sync
  /// cursor must NOT advance on the result of our own save: another member's
  /// change with an earlier `modifiedAt` may not have been downloaded yet.
  void _merge(Map<String, dynamic> raw, {required bool fromSync}) {
    final id = raw['id'] as String;
    _cache[id] = LedgerEntry.fromMap(id, raw);
    if (fromSync) {
      final m = (raw['modifiedAt'] as num?)?.toInt() ?? 0;
      if (m > _since) _since = m;
    }
  }

  /// Pulls everything changed since the last sync (following the server's paging).
  Future<List<LedgerEntry>> sync() async {
    for (var page = 0; page < 100; page++) {
      final json = await _api.get('/api/transactions', query: {'since': '$_since'});
      final entries = (json['entries'] as List?) ?? const [];
      for (final raw in entries) {
        _merge(raw as Map<String, dynamic>, fromSync: true);
      }
      if (json['nextSince'] == null) break;
    }
    return _snapshot;
  }

  /// Live-ish list of all transactions (including soft-deleted ones; the
  /// calculators and filters exclude those).
  Stream<List<LedgerEntry>> watchAll() => pollStream<List<LedgerEntry>>(
        load: sync,
        every: pollInterval,
        refreshes: _changed.stream,
      );

  /// Forces a sync now (used right before exporting a report).
  Future<void> refresh() => sync();

  void _requireValid(LedgerEntry e) {
    final issues = EntryValidator.validate(e);
    if (issues.isNotEmpty) {
      throw AppException('err_invalid_entry', issues.first.toString());
    }
  }

  void _applyServerEntry(Map<String, dynamic> json) {
    _merge(json['entry'] as Map<String, dynamic>, fromSync: false);
    _changed.add(null);
  }

  /// Creates [entry]. The id is generated once per form, so a double tap or a
  /// retry after a flaky network cannot create a second record: the server
  /// answers `created: false` and the call returns false.
  Future<bool> create(LedgerEntry entry, Actor actor) async {
    if (!Permissions.canAddEntry(actor.role)) {
      throw const AppException('err_permission');
    }
    _requireValid(entry);
    try {
      final json = await _api.post('/api/transactions', body: entry.toApiBody());
      _applyServerEntry(json);
      return json['created'] == true;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Edits [before] into [after]. Fund and type can never change.
  Future<void> update(LedgerEntry before, LedgerEntry after, Actor actor) async {
    if (!Permissions.canModifyEntry(
      role: actor.role,
      uid: actor.uid,
      entry: before,
      now: DateTime.now(),
    )) {
      throw const AppException('err_edit_not_allowed');
    }
    if (before.id != after.id || before.fund != after.fund || before.type != after.type) {
      throw const AppException('err_invalid_entry', 'id, fund and type are immutable');
    }
    _requireValid(after);
    try {
      final json = await _api.put(
        '/api/transactions/${before.id}',
        body: after.toApiBody(includeId: false),
      );
      _applyServerEntry(json);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Soft delete: the record stays (for the audit trail and for restore) but
  /// is excluded from every total, list and report.
  Future<void> softDelete(LedgerEntry entry, Actor actor) async {
    if (!Permissions.canModifyEntry(
      role: actor.role,
      uid: actor.uid,
      entry: entry,
      now: DateTime.now(),
    )) {
      throw const AppException('err_edit_not_allowed');
    }
    try {
      _applyServerEntry(await _api.post('/api/transactions/${entry.id}/delete'));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin-only: brings a soft-deleted entry back.
  Future<void> restore(LedgerEntry entry, Actor actor) async {
    if (!Permissions.canRestoreEntries(actor.role)) {
      throw const AppException('err_permission');
    }
    try {
      _applyServerEntry(await _api.post('/api/transactions/${entry.id}/restore'));
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
