import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// Search / date / type / group filter shared by every list and report.
class LedgerFilter {
  const LedgerFilter({
    this.query = '',
    this.from,
    this.to,
    this.type,
    this.groupId,
    this.includeDeleted = false,
  });

  final String query;
  final DateTime? from;
  final DateTime? to;
  final TxnType? type;
  final String? groupId;
  final bool includeDeleted;

  bool get hasDateRange => from != null || to != null;

  bool get isActive =>
      query.trim().isNotEmpty || hasDateRange || type != null || groupId != null;

  LedgerFilter copyWith({
    String? query,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    TxnType? type,
    bool clearType = false,
    String? groupId,
    bool clearGroup = false,
    bool? includeDeleted,
  }) =>
      LedgerFilter(
        query: query ?? this.query,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        type: clearType ? null : (type ?? this.type),
        groupId: clearGroup ? null : (groupId ?? this.groupId),
        includeDeleted: includeDeleted ?? this.includeDeleted,
      );

  bool matches(LedgerEntry e) {
    if (!includeDeleted && e.isDeleted) return false;
    if (type != null && e.type != type) return false;
    if (groupId != null && e.visarjanGroupId != groupId) return false;
    final d = dateOnly(e.date);
    if (from != null && d.isBefore(dateOnly(from!))) return false;
    if (to != null && d.isAfter(dateOnly(to!))) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      e.description,
      e.category,
      e.householdName,
      e.visarjanGroupName,
      e.sponsorName,
      e.contributorName,
      e.notes,
      e.createdByName,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(q);
  }

  /// Matching entries, newest first.
  List<LedgerEntry> apply(Iterable<LedgerEntry> entries) {
    final result = entries.where(matches).toList();
    result.sort(compareNewestFirst);
    return result;
  }

  static int compareNewestFirst(LedgerEntry a, LedgerEntry b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  }
}
