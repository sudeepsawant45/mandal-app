import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';

/// Income / expense totals for one scope. Balance is always derived
/// (income - expense), never stored.
class Totals {
  const Totals({this.incomePaise = 0, this.expensePaise = 0});

  final int incomePaise;
  final int expensePaise;

  int get balancePaise => incomePaise - expensePaise;

  static const zero = Totals();

  @override
  bool operator ==(Object other) =>
      other is Totals &&
      other.incomePaise == incomePaise &&
      other.expensePaise == expensePaise;

  @override
  int get hashCode => Object.hash(incomePaise, expensePaise);

  @override
  String toString() => 'Totals(income: $incomePaise, expense: $expensePaise)';
}

class HouseholdSummary {
  const HouseholdSummary({
    required this.household,
    required this.totalPaise,
    required this.donationCount,
    this.lastDonation,
  });

  final Household household;
  final int totalPaise;
  final int donationCount;
  final DateTime? lastDonation;
}

class GroupSummary {
  const GroupSummary({
    required this.group,
    required this.totals,
    required this.contributionCount,
    required this.expenseCount,
  });

  final VisarjanGroup group;
  final Totals totals;
  final int contributionCount;
  final int expenseCount;
}

class SponsorSummary {
  const SponsorSummary({
    required this.sponsor,
    required this.totalPaise,
    required this.count,
  });

  final Sponsor sponsor;
  final int totalPaise;
  final int count;
}

class TshirtSummary {
  const TshirtSummary({required this.totals, required this.quantity});

  final Totals totals;

  /// Sum of quantities recorded on T-shirt expense entries.
  final int quantity;
}

/// All money arithmetic lives here: pure functions over actual transaction
/// records. Nothing is hard-coded or cached, so editing or soft-deleting an
/// entry is reflected the next time totals are computed.
///
/// Every function ignores soft-deleted entries. Fund-specific functions filter
/// by [Fund] themselves, so an entry can never be counted in two funds.
class LedgerCalculator {
  LedgerCalculator._();

  /// Entries of exactly one fund (soft-deleted ones removed).
  static List<LedgerEntry> forFund(Iterable<LedgerEntry> entries, Fund fund) =>
      entries.where((e) => !e.isDeleted && e.fund == fund).toList();

  /// Sums a list of entries. Callers must pass entries of ONE fund; use
  /// [totalsForFund] when starting from a mixed list.
  static Totals sum(Iterable<LedgerEntry> entries) {
    var income = 0;
    var expense = 0;
    for (final e in entries) {
      if (e.isDeleted) continue;
      if (e.type == TxnType.income) {
        income += e.amountPaise;
      } else {
        expense += e.amountPaise;
      }
    }
    return Totals(incomePaise: income, expensePaise: expense);
  }

  static Totals totalsForFund(Iterable<LedgerEntry> entries, Fund fund) =>
      sum(forFund(entries, fund));

  static Map<Fund, Totals> totalsByFund(Iterable<LedgerEntry> entries) => {
        for (final f in Fund.values) f: totalsForFund(entries, f),
      };

  /// Income / expense per category within one list of single-fund entries.
  static Map<String, Totals> categoryTotals(Iterable<LedgerEntry> entries) {
    final income = <String, int>{};
    final expense = <String, int>{};
    for (final e in entries) {
      if (e.isDeleted) continue;
      final target = e.type == TxnType.income ? income : expense;
      target[e.category] = (target[e.category] ?? 0) + e.amountPaise;
    }
    final keys = {...income.keys, ...expense.keys};
    return {
      for (final k in keys)
        k: Totals(incomePaise: income[k] ?? 0, expensePaise: expense[k] ?? 0),
    };
  }

  // ------------------------------------------------------------- households

  /// One summary per household (zero for households without donations).
  /// Multiple donations from a household are separate transactions that are
  /// each counted exactly once.
  static List<HouseholdSummary> householdSummaries(
    Iterable<LedgerEntry> entries,
    Iterable<Household> households,
  ) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    final last = <String, DateTime>{};
    for (final e in forFund(entries, Fund.householdDonation)) {
      final id = e.householdId;
      if (id == null || e.type != TxnType.income) continue;
      totals[id] = (totals[id] ?? 0) + e.amountPaise;
      counts[id] = (counts[id] ?? 0) + 1;
      final prev = last[id];
      if (prev == null || e.date.isAfter(prev)) last[id] = e.date;
    }
    final result = [
      for (final h in households)
        HouseholdSummary(
          household: h,
          totalPaise: totals[h.id] ?? 0,
          donationCount: counts[h.id] ?? 0,
          lastDonation: last[h.id],
        ),
    ];
    result.sort((a, b) =>
        a.household.name.toLowerCase().compareTo(b.household.name.toLowerCase()));
    return result;
  }

  // --------------------------------------------------------------- visarjan

  /// Totals of a single visarjan account.
  static Totals visarjanTotalsForGroup(
    Iterable<LedgerEntry> entries,
    String groupId,
  ) =>
      sum(forFund(entries, Fund.visarjan).where((e) => e.visarjanGroupId == groupId));

  /// Totals across ALL visarjan accounts (the combined report).
  static Totals visarjanCombinedTotals(Iterable<LedgerEntry> entries) =>
      totalsForFund(entries, Fund.visarjan);

  static List<GroupSummary> visarjanGroupSummaries(
    Iterable<LedgerEntry> entries,
    Iterable<VisarjanGroup> groups,
  ) {
    final visarjan = forFund(entries, Fund.visarjan);
    final result = [
      for (final g in groups)
        () {
          final own = visarjan.where((e) => e.visarjanGroupId == g.id).toList();
          return GroupSummary(
            group: g,
            totals: sum(own),
            contributionCount: own.where((e) => e.type == TxnType.income).length,
            expenseCount: own.where((e) => e.type == TxnType.expense).length,
          );
        }(),
    ];
    result.sort(
        (a, b) => a.group.name.toLowerCase().compareTo(b.group.name.toLowerCase()));
    return result;
  }

  // ---------------------------------------------------------------- T-shirt

  static List<SponsorSummary> sponsorSummaries(
    Iterable<LedgerEntry> entries,
    Iterable<Sponsor> sponsors,
  ) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final e in forFund(entries, Fund.tshirtSponsorship)) {
      final id = e.sponsorId;
      if (id == null || e.type != TxnType.income) continue;
      totals[id] = (totals[id] ?? 0) + e.amountPaise;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final result = [
      for (final s in sponsors)
        SponsorSummary(
          sponsor: s,
          totalPaise: totals[s.id] ?? 0,
          count: counts[s.id] ?? 0,
        ),
    ];
    result.sort(
        (a, b) => a.sponsor.name.toLowerCase().compareTo(b.sponsor.name.toLowerCase()));
    return result;
  }

  static TshirtSummary tshirtSummary(Iterable<LedgerEntry> entries) {
    final own = forFund(entries, Fund.tshirtSponsorship);
    var qty = 0;
    for (final e in own) {
      if (e.type == TxnType.expense) qty += e.quantity ?? 0;
    }
    return TshirtSummary(totals: sum(own), quantity: qty);
  }
}
