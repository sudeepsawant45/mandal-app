import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// Entries (incl. soft-deleted) of one fund, derived from the single
/// all-transactions stream so every screen sees the same data.
final fundEntriesProvider = Provider.autoDispose
    .family<AsyncValue<List<LedgerEntry>>, Fund>((ref, fund) {
  return ref
      .watch(allEntriesProvider)
      .whenData((all) => all.where((e) => e.fund == fund).toList());
});

/// Totals of one fund, computed from actual (non-deleted) records.
final fundTotalsProvider =
    Provider.autoDispose.family<AsyncValue<Totals>, Fund>((ref, fund) {
  return ref
      .watch(allEntriesProvider)
      .whenData((all) => LedgerCalculator.totalsForFund(all, fund));
});
