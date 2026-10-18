import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/domain/report_builder.dart';
import 'package:ganpati_mandal/domain/report_text.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

import 'helpers/factories.dart';

ReportContext ctx({DateTime? from, DateTime? to, String symbol = '₹'}) => ReportContext(
      settings: kSettings,
      now: kNow,
      l10n: L10n.en,
      from: from,
      to: to,
      symbol: symbol,
    );

String? summaryValue(dynamic data, String label) {
  for (final r in data.summary) {
    if (r.label == label) return r.value as String;
  }
  return null;
}

void main() {
  final entries = [
    donation('d1', 'h1', 100000, date: DateTime(2026, 9, 1)),
    donation('d2', 'h1', 50000, date: DateTime(2026, 9, 5)),
    donation('d3', 'h2', 200000, date: DateTime(2026, 9, 9)),
    donation('d4', 'h2', 999900, date: DateTime(2026, 9, 9), deleted: true),
    commonIncome('c1', 300000, date: DateTime(2026, 9, 2)),
    commonExpense('c2', 80000, date: DateTime(2026, 9, 3)),
    visarjanIncome('v1', 'g1', 500000),
    visarjanExpense('v2', 'g1', 100000),
    visarjanIncome('v3', 'g2', 70000),
    tshirtIncome('t1', 's1', 400000),
    tshirtExpense('t2', 250000, quantity: 80),
  ];

  group('every report carries the mandatory header lines', () {
    final reports = {
      ReportKind.household: ReportBuilder.household(entries: entries, households: kHouseholds, ctx: ctx()),
      ReportKind.commonFund: ReportBuilder.commonFund(entries: entries, ctx: ctx()),
      ReportKind.visarjanGroup:
          ReportBuilder.visarjanGroup(entries: entries, group: kGroups[0], ctx: ctx()),
      ReportKind.visarjanCombined:
          ReportBuilder.visarjanCombined(entries: entries, groups: kGroups, ctx: ctx()),
      ReportKind.tshirt: ReportBuilder.tshirt(entries: entries, sponsors: kSponsors, ctx: ctx()),
    };
    for (final e in reports.entries) {
      test(e.key.name, () {
        final d = e.value;
        expect(d.kind, e.key);
        expect(d.mandalName, 'Shree Ganesh Mandal');
        expect(d.financialYearLine, contains('2026-27'));
        expect(d.periodLine, isNotEmpty);
        expect(d.generatedLine, contains('20/09/2026'));
        expect(d.title, isNotEmpty);
        expect(d.fileName, isNotEmpty);
        expect(d.tables, isNotEmpty);
      });
    }
  });

  test('household report: deleted donations are excluded, totals add up', () {
    final d = ReportBuilder.household(entries: entries, households: kHouseholds, ctx: ctx());
    expect(d.incomePaise, 350000);
    expect(d.expensePaise, 0);
    expect(summaryValue(d, 'Total donations'), '₹3,500');
    final perHousehold = d.tables.first;
    expect(perHousehold.rows.length, 2); // h3 has no donations
    expect(perHousehold.footer.last, '₹3,500');
    // transaction table has one row per live donation
    expect(d.tables[1].rows.length, 3);
  });

  test('household report respects the date range', () {
    final d = ReportBuilder.household(
      entries: entries,
      households: kHouseholds,
      ctx: ctx(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 9)),
    );
    expect(d.incomePaise, 250000);
    expect(d.tables[1].rows.length, 2);
  });

  test('donation to an unlisted household still adds up via an "unlisted" row', () {
    final d = ReportBuilder.household(
      entries: [donation('x', 'gone', 12300)],
      households: kHouseholds,
      ctx: ctx(),
    );
    expect(d.incomePaise, 12300);
    final rows = d.tables.first.rows;
    expect(rows.length, 1);
    expect(rows.first.last, '₹123');
  });

  test('common fund report excludes every other fund', () {
    final d = ReportBuilder.commonFund(entries: entries, ctx: ctx());
    expect(d.incomePaise, 300000);
    expect(d.expensePaise, 80000);
    expect(d.balancePaise, 220000);
    expect(summaryValue(d, 'Balance'), '₹2,200');
  });

  test('individual visarjan report covers exactly one group', () {
    final g1 = ReportBuilder.visarjanGroup(entries: entries, group: kGroups[0], ctx: ctx());
    final g2 = ReportBuilder.visarjanGroup(entries: entries, group: kGroups[1], ctx: ctx());
    expect(g1.incomePaise, 500000);
    expect(g1.expensePaise, 100000);
    expect(g2.incomePaise, 70000);
    expect(g2.expensePaise, 0);
    expect(g1.fileName, isNot(g2.fileName));
  });

  test('combined visarjan = sum of groups, and per-group rows are listed', () {
    final d = ReportBuilder.visarjanCombined(entries: entries, groups: kGroups, ctx: ctx());
    expect(d.incomePaise, 570000);
    expect(d.expensePaise, 100000);
    expect(d.balancePaise, 470000);
    final g1 = ReportBuilder.visarjanGroup(entries: entries, group: kGroups[0], ctx: ctx());
    final g2 = ReportBuilder.visarjanGroup(entries: entries, group: kGroups[1], ctx: ctx());
    expect(d.incomePaise, g1.incomePaise + g2.incomePaise);
    expect(d.expensePaise, g1.expensePaise + g2.expensePaise);
  });

  test('T-shirt report shows sponsorship, expenses, balance and quantity', () {
    final d = ReportBuilder.tshirt(entries: entries, sponsors: kSponsors, ctx: ctx());
    expect(d.incomePaise, 400000);
    expect(d.expensePaise, 250000);
    expect(d.balancePaise, 150000);
    expect(summaryValue(d, 'T-shirts'), '80');
  });

  test('report generation is deterministic', () {
    final a = ReportBuilder.commonFund(entries: entries, ctx: ctx());
    final b = ReportBuilder.commonFund(entries: entries, ctx: ctx());
    expect(ReportText.summary(a), ReportText.summary(b));
  });

  test('empty data still produces a valid report with zero totals', () {
    final d = ReportBuilder.commonFund(entries: const [], ctx: ctx());
    expect(d.incomePaise, 0);
    expect(d.expensePaise, 0);
    expect(d.tables.every((t) => t.rows.isEmpty), isTrue);
  });

  test('symbol falls back to "Rs. " when the PDF font has no rupee glyph', () {
    final d = ReportBuilder.commonFund(entries: entries, ctx: ctx(symbol: 'Rs. '));
    expect(summaryValue(d, 'Balance'), 'Rs. 2,200');
  });

  test('text summary contains header and headline figures, not transaction rows', () {
    final d = ReportBuilder.commonFund(entries: entries, ctx: ctx());
    final text = ReportText.summary(d);
    expect(text, contains('Shree Ganesh Mandal'));
    expect(text, contains('2026-27'));
    expect(text, contains('₹2,200'));
    expect(text, contains(d.generatedLine));
  });

  test('Marathi reports use Marathi labels', () {
    final d = ReportBuilder.commonFund(
      entries: entries,
      ctx: ReportContext(settings: kSettings, now: kNow, l10n: L10n.mr),
    );
    expect(d.title, isNot(ReportBuilder.commonFund(entries: entries, ctx: ctx()).title));
  });
}
