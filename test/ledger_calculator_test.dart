import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

import 'helpers/factories.dart';

void main() {
  group('balance = income - expense', () {
    test('common fund', () {
      final entries = [
        commonIncome('c1', 500000), // 5,000
        commonIncome('c2', 25050), // 250.50
        commonExpense('c3', 120050), // 1,200.50
      ];
      final t = LedgerCalculator.totalsForFund(entries, Fund.commonMandal);
      expect(t.incomePaise, 525050);
      expect(t.expensePaise, 120050);
      expect(t.balancePaise, 405000);
    });

    test('balance can be negative when expenses exceed income', () {
      final t = LedgerCalculator.sum([commonIncome('a', 1000), commonExpense('b', 5000)]);
      expect(t.balancePaise, -4000);
    });

    test('empty list gives zero totals', () {
      expect(LedgerCalculator.sum(const []), Totals.zero);
      expect(Totals.zero.balancePaise, 0);
    });

    test('integer paise: no floating point drift', () {
      final entries = [
        for (var i = 0; i < 1000; i++) commonIncome('i$i', 10), // 1000 x 0.10
      ];
      expect(LedgerCalculator.sum(entries).incomePaise, 10000);
    });
  });

  group('household donations', () {
    final entries = [
      donation('d1', 'h1', 100000), // 1,000
      donation('d2', 'h1', 50000), // 500
      donation('d3', 'h1', 25050), // 250.50
      donation('d4', 'h2', 200000), // 2,000
    ];

    test('multiple donations from the same household stay separate and add up', () {
      final summaries = LedgerCalculator.householdSummaries(entries, kHouseholds);
      final patil = summaries.firstWhere((s) => s.household.id == 'h1');
      final deshmukh = summaries.firstWhere((s) => s.household.id == 'h2');
      final joshi = summaries.firstWhere((s) => s.household.id == 'h3');

      expect(patil.donationCount, 3);
      expect(patil.totalPaise, 175050);
      expect(deshmukh.donationCount, 1);
      expect(deshmukh.totalPaise, 200000);
      expect(joshi.donationCount, 0);
      expect(joshi.totalPaise, 0);
    });

    test('household-wise totals sum to the overall total (nothing counted twice)', () {
      final summaries = LedgerCalculator.householdSummaries(entries, kHouseholds);
      final byHousehold = summaries.fold<int>(0, (a, s) => a + s.totalPaise);
      final overall = LedgerCalculator.totalsForFund(entries, Fund.householdDonation);
      expect(byHousehold, overall.incomePaise);
      expect(overall.incomePaise, 375050);
      expect(overall.expensePaise, 0);
    });

    test('summaries are sorted by household name', () {
      final names = LedgerCalculator.householdSummaries(entries, kHouseholds)
          .map((s) => s.household.name)
          .toList();
      expect(names, ['Deshmukh', 'Joshi', 'Patil']);
    });

    test('last donation date is tracked', () {
      final list = [
        donation('a', 'h1', 100, date: DateTime(2026, 9, 1)),
        donation('b', 'h1', 100, date: DateTime(2026, 9, 9)),
        donation('c', 'h1', 100, date: DateTime(2026, 9, 5)),
      ];
      final s = LedgerCalculator.householdSummaries(list, kHouseholds)
          .firstWhere((x) => x.household.id == 'h1');
      expect(s.lastDonation, DateTime(2026, 9, 9));
    });
  });

  group('visarjan accounts are independent', () {
    final entries = [
      visarjanIncome('v1', 'g1', 300000, contributor: 'A'),
      visarjanIncome('v2', 'g1', 200000, contributor: 'B'),
      visarjanExpense('v3', 'g1', 100000),
      visarjanIncome('v4', 'g2', 50000),
      visarjanExpense('v5', 'g2', 70000),
    ];

    test('per-group totals', () {
      final g1 = LedgerCalculator.visarjanTotalsForGroup(entries, 'g1');
      expect(g1.incomePaise, 500000);
      expect(g1.expensePaise, 100000);
      expect(g1.balancePaise, 400000);

      final g2 = LedgerCalculator.visarjanTotalsForGroup(entries, 'g2');
      expect(g2.incomePaise, 50000);
      expect(g2.expensePaise, 70000);
      expect(g2.balancePaise, -20000);
    });

    test('a group with no entries has zero totals', () {
      expect(LedgerCalculator.visarjanTotalsForGroup(entries, 'g3'), Totals.zero);
    });

    test('adding an entry to one group does not change another group', () {
      final before = LedgerCalculator.visarjanTotalsForGroup(entries, 'g2');
      final after = LedgerCalculator.visarjanTotalsForGroup(
        [...entries, visarjanIncome('v6', 'g1', 999900)],
        'g2',
      );
      expect(after, before);
    });

    test('group summaries count contributions and expenses', () {
      final s = LedgerCalculator.visarjanGroupSummaries(entries, kGroups);
      final g1 = s.firstWhere((x) => x.group.id == 'g1');
      expect(g1.contributionCount, 2);
      expect(g1.expenseCount, 1);
    });

    test('combined totals equal the sum of the individual groups', () {
      final combined = LedgerCalculator.visarjanCombinedTotals(entries);
      final perGroup = LedgerCalculator.visarjanGroupSummaries(entries, kGroups);
      final income = perGroup.fold<int>(0, (a, s) => a + s.totals.incomePaise);
      final expense = perGroup.fold<int>(0, (a, s) => a + s.totals.expensePaise);
      expect(combined.incomePaise, income);
      expect(combined.expensePaise, expense);
      expect(combined.incomePaise, 550000);
      expect(combined.expensePaise, 170000);
      expect(combined.balancePaise, 380000);
    });
  });

  group('T-shirt sponsorship', () {
    final entries = [
      tshirtIncome('t1', 's1', 500000),
      tshirtIncome('t2', 's1', 100000),
      tshirtIncome('t3', 's2', 250000),
      tshirtExpense('t4', 600000, quantity: 120),
      tshirtExpense('t5', 50000, quantity: 10),
      tshirtExpense('t6', 10000), // no quantity recorded
    ];

    test('totals and remaining balance', () {
      final s = LedgerCalculator.tshirtSummary(entries);
      expect(s.totals.incomePaise, 850000);
      expect(s.totals.expensePaise, 660000);
      expect(s.totals.balancePaise, 190000);
    });

    test('quantity is summed over expense entries only', () {
      expect(LedgerCalculator.tshirtSummary(entries).quantity, 130);
    });

    test('sponsor-wise contributions', () {
      final per = LedgerCalculator.sponsorSummaries(entries, kSponsors);
      final abc = per.firstWhere((s) => s.sponsor.id == 's1');
      final xyz = per.firstWhere((s) => s.sponsor.id == 's2');
      expect(abc.totalPaise, 600000);
      expect(abc.count, 2);
      expect(xyz.totalPaise, 250000);
      expect(per.fold<int>(0, (a, s) => a + s.totalPaise), 850000);
    });
  });

  group('no double counting between funds', () {
    final entries = <LedgerEntry>[
      donation('d1', 'h1', 100000),
      commonIncome('c1', 200000),
      commonExpense('c2', 50000),
      visarjanIncome('v1', 'g1', 300000),
      visarjanExpense('v2', 'g1', 40000),
      tshirtIncome('t1', 's1', 500000),
      tshirtExpense('t2', 60000),
    ];

    test('each fund only counts its own entries', () {
      final byFund = LedgerCalculator.totalsByFund(entries);
      expect(byFund[Fund.householdDonation]!.incomePaise, 100000);
      expect(byFund[Fund.householdDonation]!.expensePaise, 0);
      expect(byFund[Fund.commonMandal]!.incomePaise, 200000);
      expect(byFund[Fund.commonMandal]!.expensePaise, 50000);
      expect(byFund[Fund.visarjan]!.incomePaise, 300000);
      expect(byFund[Fund.visarjan]!.expensePaise, 40000);
      expect(byFund[Fund.tshirtSponsorship]!.incomePaise, 500000);
      expect(byFund[Fund.tshirtSponsorship]!.expensePaise, 60000);
    });

    test('a donation never leaks into the common fund', () {
      final withoutDonation = entries.where((e) => e.fund != Fund.householdDonation);
      expect(
        LedgerCalculator.totalsForFund(entries, Fund.commonMandal),
        LedgerCalculator.totalsForFund(withoutDonation, Fund.commonMandal),
      );
    });

    test('per-fund totals partition the grand total exactly', () {
      final byFund = LedgerCalculator.totalsByFund(entries);
      final partIncome = byFund.values.fold<int>(0, (a, t) => a + t.incomePaise);
      final partExpense = byFund.values.fold<int>(0, (a, t) => a + t.expensePaise);
      final all = LedgerCalculator.sum(entries);
      expect(partIncome, all.incomePaise);
      expect(partExpense, all.expensePaise);
    });

    test('forFund returns only that fund', () {
      expect(
        LedgerCalculator.forFund(entries, Fund.visarjan).every((e) => e.fund == Fund.visarjan),
        isTrue,
      );
      expect(LedgerCalculator.forFund(entries, Fund.visarjan).length, 2);
    });
  });

  group('edits and removals recalculate correctly', () {
    test('soft-deleted entries are excluded from every total', () {
      final entries = [
        commonIncome('c1', 100000),
        commonIncome('c2', 50000, deleted: true),
        commonExpense('c3', 20000, deleted: true),
      ];
      final t = LedgerCalculator.totalsForFund(entries, Fund.commonMandal);
      expect(t.incomePaise, 100000);
      expect(t.expensePaise, 0);
    });

    test('editing an amount changes the totals; removing it changes them again', () {
      var entries = [donation('d1', 'h1', 100000), donation('d2', 'h1', 50000)];
      expect(LedgerCalculator.totalsForFund(entries, Fund.householdDonation).incomePaise, 150000);

      // edit d2: 500 -> 750
      entries = [entries[0], donation('d2', 'h1', 75000)];
      expect(LedgerCalculator.totalsForFund(entries, Fund.householdDonation).incomePaise, 175000);

      // soft-delete d1
      entries = [donation('d1', 'h1', 100000, deleted: true), entries[1]];
      expect(LedgerCalculator.totalsForFund(entries, Fund.householdDonation).incomePaise, 75000);
      final h1 = LedgerCalculator.householdSummaries(entries, kHouseholds)
          .firstWhere((s) => s.household.id == 'h1');
      expect(h1.donationCount, 1);
    });

    test('visarjan balance follows edits and deletions', () {
      var entries = [
        visarjanIncome('v1', 'g1', 100000),
        visarjanExpense('v2', 'g1', 30000),
      ];
      expect(LedgerCalculator.visarjanTotalsForGroup(entries, 'g1').balancePaise, 70000);
      entries = [visarjanIncome('v1', 'g1', 100000), visarjanExpense('v2', 'g1', 30000, deleted: true)];
      expect(LedgerCalculator.visarjanTotalsForGroup(entries, 'g1').balancePaise, 100000);
    });
  });

  test('categoryTotals groups income and expense by category', () {
    final entries = [
      commonIncome('a', 1000),
      commonExpense('b', 400, category: 'puja_materials'),
      commonExpense('c', 100, category: 'puja_materials'),
      commonExpense('d', 50, category: 'bhajan_instruments'),
    ];
    final totals = LedgerCalculator.categoryTotals(entries);
    expect(totals['general_income'], const Totals(incomePaise: 1000));
    expect(totals['puja_materials'], const Totals(expensePaise: 500));
    expect(totals['bhajan_instruments'], const Totals(expensePaise: 50));
  });
}
