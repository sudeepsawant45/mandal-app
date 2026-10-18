import 'package:ganpati_mandal/core/utils/date_utils.dart';

/// One immutable line of the audit trail (audit_logs/{id}).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.summary,
    required this.userId,
    required this.userName,
    this.at,
    this.before,
    this.after,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final String summary;
  final String userId;
  final String userName;
  final DateTime? at;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  factory AuditEntry.fromMap(String id, Map<String, dynamic> m) => AuditEntry(
        id: id,
        entityType: (m['entityType'] as String?) ?? '',
        entityId: (m['entityId'] as String?) ?? '',
        action: (m['action'] as String?) ?? '',
        summary: (m['summary'] as String?) ?? '',
        userId: (m['userId'] as String?) ?? '',
        userName: (m['userName'] as String?) ?? '',
        at: readDate(m['at']),
        before: (m['before'] as Map?)?.cast<String, dynamic>(),
        after: (m['after'] as Map?)?.cast<String, dynamic>(),
      );
}
