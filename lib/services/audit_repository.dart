import 'package:ganpati_mandal/models/audit_entry.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/polling.dart';

/// Read-only audit trail via /api/audit. Audit lines are written by the server
/// in the same transaction as the change they describe; the app cannot write them.
class AuditRepository {
  AuditRepository(this._api);

  final ApiClient _api;

  Future<List<AuditEntry>> fetch({int limit = 100}) async {
    final json = await _api.get('/api/audit', query: {'limit': '$limit'});
    final items = (json['entries'] as List?) ?? const [];
    return [
      for (final raw in items)
        AuditEntry.fromMap((raw as Map<String, dynamic>)['id'] as String, raw),
    ];
  }

  Stream<List<AuditEntry>> watchRecent({int limit = 100}) => pollStream<List<AuditEntry>>(
        load: () => fetch(limit: limit),
        every: const Duration(minutes: 2),
      );
}
