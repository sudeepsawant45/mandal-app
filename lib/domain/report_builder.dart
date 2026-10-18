import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/domain/ledger_filter.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/mandal_settings.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';
import 'package:ganpati_mandal/domain/report_models.dart';

/// Shared inputs for every report.
class ReportContext {
  const ReportContext({
    required this.settings,
    required this.now,
    required this.l10n,
    this.from,
    this.to,
    this.symbol = Money.rupeeSymbol,
  });

  final MandalSettings settings;
  final DateTime now;
  final L10n l10n;
  final DateTime? from;
  final DateTime? to;

  /// Currency prefix. "₹" normally; "Rs. " when the PDF font has no rupee glyph.
  final String symbol;
}

/// Turns raw entries into [ReportData]. Pure and deterministic: the same entries
/// always give the same numbers, and every figure is computed from the actual
/// (non-deleted) transaction records of exactly one fund.
class ReportBuilder {
  ReportBuilder._();

  // ----------------------------------------------------------------- helpers
  static String _m(ReportContext c, int paise) =>
      Money.format(paise, symbol: c.symbol);

  static List<LedgerEntry> _inPeriod(
    ReportContext c,
    Iterable<LedgerEntry> entries, {
    String? groupId,
  }) {
    final filtered = LedgerFilter(from: c.from, to: c.to, groupId: groupId).apply(entries);
    // Reports read chronologically (oldest first).
    return filtered.reversed.toList();
  }

  static String _safeName(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned;
  }

  static ReportData _assemble(
    ReportContext c, {
    required ReportKind kind,
    required String titleKey,
    required String fileName,
    required List<ReportSummaryRow> summary,
    required List<ReportTable> tables,
    required int income,
    required int expense,
    String? subtitle,
  }) {
    final l = c.l10n;
    final period = periodText(
      c.from,
      c.to,
      allLabel: l.t('all_dates'),
      fromWord: l.t('from_word'),
      untilWord: l.t('until_word'),
    );
    return ReportData(
      kind: kind,
      title: l.t(titleKey),
      subtitle: subtitle,
      mandalName: c.settings.mandalName,
      financialYearLine: '${l.t('financial_year')}: ${c.settings.financialYear}',
      periodLine: '${l.t('period')}: $period',
      generatedLine: '${l.t('generated_on')}: ${formatDateTime(c.now)}',
      pageWord: l.t('page'),
      fileName: fileName,
      summary: summary,
      tables: tables,
      incomePaise: income,
      expensePaise: expense,
    );
  }

  static String _nameOf(Map<String, String> byId, String? id, String? snapshot) =>
      (id == null ? null : byId[id]) ?? snapshot ?? '';

  // --------------------------------------------------------------- household
  static ReportData household({
    required Iterable<LedgerEntry> entries,
    required Iterable<Household> households,
    required ReportContext ctx,
  }) {
    final l = ctx.l10n;
    final scoped = _inPeriod(ctx, LedgerCalculator.forFund(entries, Fund.householdDonation));
    final totals = LedgerCalculator.sum(scoped);
    final names = {for (final h in households) h.id: h.name};

    final perHousehold = LedgerCalculator.householdSummaries(scoped, households)
        .where((s) => s.donationCount > 0)
        .toList();
    final listedTotal = perHousehold.fold<int>(0, (a, s) => a + s.totalPaise);
    final listedCount = perHousehold.fold<int>(0, (a, s) => a + s.donationCount);
    final summaryRows = [
      for (final s in perHousehold)
        [s.household.name, '${s.donationCount}', _m(ctx, s.totalPaise)],
    ];
    // Entries pointing at a household that is not in the list still count in
    // the grand total; show them explicitly so the table always adds up.
    if (listedTotal != totals.incomePaise) {
      summaryRows.add([
        l.t('unlisted'),
        '${scoped.length - listedCount}',
        _m(ctx, totals.incomePaise - listedTotal),
      ]);
    }

    return _assemble(
      ctx,
      kind: ReportKind.household,
      titleKey: 'report_household',
      fileName: 'household_donations',
      income: totals.incomePaise,
      expense: 0,
      summary: [
        ReportSummaryRow(l.t('total_donations'), _m(ctx, totals.incomePaise), emphasize: true),
        ReportSummaryRow(l.t('donation_count'), '${scoped.length}'),
        ReportSummaryRow(l.t('households_contributed'), '${perHousehold.length}'),
      ],
      tables: [
        ReportTable(
          title: l.t('household_wise'),
          headers: [l.t('household'), l.t('donation_count'), l.t('total')],
          rows: summaryRows,
          footer: [l.t('total'), '${scoped.length}', _m(ctx, totals.incomePaise)],
          rightAligned: const {1, 2},
          columnFlex: const [3, 1.2, 1.8],
          emptyText: l.t('no_transactions'),
        ),
        ReportTable(
          title: l.t('transactions'),
          headers: [
            l.t('date'),
            l.t('household'),
            l.t('contributor'),
            l.t('method'),
            l.t('amount'),
            l.t('note'),
          ],
          rows: [
            for (final e in scoped)
              [
                formatDate(e.date),
                _nameOf(names, e.householdId, e.householdName),
                e.contributorName ?? '',
                l.paymentMethod(e.paymentMethod),
                _m(ctx, e.amountPaise),
                e.notes ?? '',
              ],
          ],
          rightAligned: const {4},
          columnFlex: const [1.3, 2, 2, 1.1, 1.5, 2],
          emptyText: l.t('no_transactions'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ common fund
  static ReportData commonFund({
    required Iterable<LedgerEntry> entries,
    required ReportContext ctx,
  }) {
    final l = ctx.l10n;
    final scoped = _inPeriod(ctx, LedgerCalculator.forFund(entries, Fund.commonMandal));
    final totals = LedgerCalculator.sum(scoped);
    final byCategory = LedgerCalculator.categoryTotals(scoped);
    final categoryKeys = byCategory.keys.toList()..sort();

    return _assemble(
      ctx,
      kind: ReportKind.commonFund,
      titleKey: 'report_common',
      fileName: 'common_mandal_fund',
      income: totals.incomePaise,
      expense: totals.expensePaise,
      summary: [
        ReportSummaryRow(l.t('income'), _m(ctx, totals.incomePaise)),
        ReportSummaryRow(l.t('expense'), _m(ctx, totals.expensePaise)),
        ReportSummaryRow(l.t('balance'), _m(ctx, totals.balancePaise), emphasize: true),
      ],
      tables: [
        ReportTable(
          title: l.t('category_wise'),
          headers: [l.t('category'), l.t('income'), l.t('expense')],
          rows: [
            for (final k in categoryKeys)
              [
                l.category(k),
                _m(ctx, byCategory[k]!.incomePaise),
                _m(ctx, byCategory[k]!.expensePaise),
              ],
          ],
          footer: [l.t('total'), _m(ctx, totals.incomePaise), _m(ctx, totals.expensePaise)],
          rightAligned: const {1, 2},
          columnFlex: const [3, 2, 2],
          emptyText: l.t('no_transactions'),
        ),
        ReportTable(
          title: l.t('transactions'),
          headers: [
            l.t('date'),
            l.t('category'),
            l.t('description'),
            l.t('income'),
            l.t('expense'),
            l.t('recorded_by'),
          ],
          rows: [
            for (final e in scoped)
              [
                formatDate(e.date),
                l.category(e.category),
                e.description,
                e.isIncome ? _m(ctx, e.amountPaise) : '',
                e.isExpense ? _m(ctx, e.amountPaise) : '',
                e.createdByName,
              ],
          ],
          footer: [
            l.t('total'),
            '',
            '',
            _m(ctx, totals.incomePaise),
            _m(ctx, totals.expensePaise),
            '',
          ],
          rightAligned: const {3, 4},
          columnFlex: const [1.3, 1.8, 2.6, 1.5, 1.5, 1.5],
          emptyText: l.t('no_transactions'),
        ),
      ],
    );
  }

  // ------------------------------------------------------- visarjan: single
  static ReportData visarjanGroup({
    required Iterable<LedgerEntry> entries,
    required VisarjanGroup group,
    required ReportContext ctx,
  }) {
    final l = ctx.l10n;
    final scoped = _inPeriod(
      ctx,
      LedgerCalculator.forFund(entries, Fund.visarjan),
      groupId: group.id,
    );
    final totals = LedgerCalculator.sum(scoped);
    final contributions = scoped.where((e) => e.isIncome).toList();
    final expenses = scoped.where((e) => e.isExpense).toList();

    return _assemble(
      ctx,
      kind: ReportKind.visarjanGroup,
      titleKey: 'report_visarjan_group',
      subtitle: group.name,
      fileName: 'visarjan_${_safeName(group.name)}',
      income: totals.incomePaise,
      expense: totals.expensePaise,
      summary: [
        ReportSummaryRow(l.t('total_contributions'), _m(ctx, totals.incomePaise)),
        ReportSummaryRow(l.t('total_expenses'), _m(ctx, totals.expensePaise)),
        ReportSummaryRow(l.t('balance'), _m(ctx, totals.balancePaise), emphasize: true),
      ],
      tables: [
        ReportTable(
          title: l.t('contributions'),
          headers: [l.t('date'), l.t('contributor'), l.t('method'), l.t('note'), l.t('amount')],
          rows: [
            for (final e in contributions)
              [
                formatDate(e.date),
                e.contributorName ?? '',
                l.paymentMethod(e.paymentMethod),
                e.notes ?? '',
                _m(ctx, e.amountPaise),
              ],
          ],
          footer: ['', '', '', l.t('total'), _m(ctx, totals.incomePaise)],
          rightAligned: const {4},
          columnFlex: const [1.3, 2.4, 1.2, 2.4, 1.6],
          emptyText: l.t('no_transactions'),
        ),
        ReportTable(
          title: l.t('expenses'),
          headers: [l.t('date'), l.t('description'), l.t('note'), l.t('amount')],
          rows: [
            for (final e in expenses)
              [
                formatDate(e.date),
                e.description,
                e.notes ?? '',
                _m(ctx, e.amountPaise),
              ],
          ],
          footer: ['', '', l.t('total'), _m(ctx, totals.expensePaise)],
          rightAligned: const {3},
          columnFlex: const [1.3, 3.4, 2.4, 1.6],
          emptyText: l.t('no_transactions'),
        ),
      ],
    );
  }

  // ----------------------------------------------------- visarjan: combined
  static ReportData visarjanCombined({
    required Iterable<LedgerEntry> entries,
    required Iterable<VisarjanGroup> groups,
    required ReportContext ctx,
  }) {
    final l = ctx.l10n;
    final scoped = _inPeriod(ctx, LedgerCalculator.forFund(entries, Fund.visarjan));
    final totals = LedgerCalculator.sum(scoped);
    final names = {for (final g in groups) g.id: g.name};
    final perGroup = LedgerCalculator.visarjanGroupSummaries(scoped, groups)
        .where((s) => s.contributionCount + s.expenseCount > 0)
        .toList();

    final listed = perGroup.fold<Totals>(
      Totals.zero,
      (a, s) => Totals(
        incomePaise: a.incomePaise + s.totals.incomePaise,
        expensePaise: a.expensePaise + s.totals.expensePaise,
      ),
    );
    final groupRows = [
      for (final s in perGroup)
        [
          s.group.name,
          _m(ctx, s.totals.incomePaise),
          _m(ctx, s.totals.expensePaise),
          _m(ctx, s.totals.balancePaise),
        ],
    ];
    if (listed != totals) {
      final rest = Totals(
        incomePaise: totals.incomePaise - listed.incomePaise,
        expensePaise: totals.expensePaise - listed.expensePaise,
      );
      groupRows.add([
        l.t('unlisted'),
        _m(ctx, rest.incomePaise),
        _m(ctx, rest.expensePaise),
        _m(ctx, rest.balancePaise),
      ]);
    }

    return _assemble(
      ctx,
      kind: ReportKind.visarjanCombined,
      titleKey: 'report_visarjan_combined',
      fileName: 'visarjan_combined',
      income: totals.incomePaise,
      expense: totals.expensePaise,
      summary: [
        ReportSummaryRow(l.t('total_contributions'), _m(ctx, totals.incomePaise)),
        ReportSummaryRow(l.t('total_expenses'), _m(ctx, totals.expensePaise)),
        ReportSummaryRow(l.t('balance'), _m(ctx, totals.balancePaise), emphasize: true),
        ReportSummaryRow(l.t('group_count'), '${perGroup.length}'),
      ],
      tables: [
        ReportTable(
          title: l.t('group_wise'),
          headers: [l.t('group'), l.t('contributions'), l.t('expenses'), l.t('balance')],
          rows: groupRows,
          footer: [
            l.t('total'),
            _m(ctx, totals.incomePaise),
            _m(ctx, totals.expensePaise),
            _m(ctx, totals.balancePaise),
          ],
          rightAligned: const {1, 2, 3},
          columnFlex: const [3, 2, 2, 2],
          emptyText: l.t('no_transactions'),
        ),
        ReportTable(
          title: l.t('transactions'),
          headers: [
            l.t('date'),
            l.t('group'),
            l.t('contributor_or_description'),
            l.t('contributions'),
            l.t('expenses'),
          ],
          rows: [
            for (final e in scoped)
              [
                formatDate(e.date),
                _nameOf(names, e.visarjanGroupId, e.visarjanGroupName),
                e.isIncome ? (e.contributorName ?? '') : e.description,
                e.isIncome ? _m(ctx, e.amountPaise) : '',
                e.isExpense ? _m(ctx, e.amountPaise) : '',
              ],
          ],
          footer: [
            l.t('total'),
            '',
            '',
            _m(ctx, totals.incomePaise),
            _m(ctx, totals.expensePaise),
          ],
          rightAligned: const {3, 4},
          columnFlex: const [1.3, 2.2, 2.8, 1.6, 1.6],
          emptyText: l.t('no_transactions'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ T-shirt
  static ReportData tshirt({
    required Iterable<LedgerEntry> entries,
    required Iterable<Sponsor> sponsors,
    required ReportContext ctx,
  }) {
    final l = ctx.l10n;
    final scoped = _inPeriod(ctx, LedgerCalculator.forFund(entries, Fund.tshirtSponsorship));
    final summary = LedgerCalculator.tshirtSummary(scoped);
    final totals = summary.totals;
    final names = {for (final s in sponsors) s.id: s.name};
    final perSponsor = LedgerCalculator.sponsorSummaries(scoped, sponsors)
        .where((s) => s.count > 0)
        .toList();
    final sponsorships = scoped.where((e) => e.isIncome).toList();
    final expenses = scoped.where((e) => e.isExpense).toList();

    final listedTotal = perSponsor.fold<int>(0, (a, s) => a + s.totalPaise);
    final listedCount = perSponsor.fold<int>(0, (a, s) => a + s.count);
    final sponsorRows = [
      for (final s in perSponsor) [s.sponsor.name, '${s.count}', _m(ctx, s.totalPaise)],
    ];
    if (listedTotal != totals.incomePaise) {
      sponsorRows.add([
        l.t('unlisted'),
        '${sponsorships.length - listedCount}',
        _m(ctx, totals.incomePaise - listedTotal),
      ]);
    }

    return _assemble(
      ctx,
      kind: ReportKind.tshirt,
      titleKey: 'report_tshirt',
      fileName: 'tshirt_sponsorship',
      income: totals.incomePaise,
      expense: totals.expensePaise,
      summary: [
        ReportSummaryRow(l.t('sponsorship_received'), _m(ctx, totals.incomePaise)),
        ReportSummaryRow(l.t('tshirt_expenses'), _m(ctx, totals.expensePaise)),
        ReportSummaryRow(l.t('balance'), _m(ctx, totals.balancePaise), emphasize: true),
        if (summary.quantity > 0) ReportSummaryRow(l.t('tshirt_quantity'), '${summary.quantity}'),
      ],
      tables: [
        ReportTable(
          title: l.t('sponsor_wise'),
          headers: [l.t('sponsor'), l.t('count'), l.t('total')],
          rows: sponsorRows,
          footer: [l.t('total'), '${sponsorships.length}', _m(ctx, totals.incomePaise)],
          rightAligned: const {1, 2},
          columnFlex: const [3, 1.2, 1.8],
          emptyText: l.t('no_transactions'),
        ),
        ReportTable(
          title: l.t('sponsorships'),
          headers: [l.t('date'), l.t('sponsor'), l.t('note'), l.t('amount')],
          rows: [
            for (final e in sponsorships)
              [
                formatDate(e.date),
                _nameOf(names, e.sponsorId, e.sponsorName),
                e.notes ?? '',
                _m(ctx, e.amountPaise),
              ],
          ],
          footer: ['', '', l.t('total'), _m(ctx, totals.incomePaise)],
          rightAligned: const {3},
          columnFlex: const [1.3, 2.6, 2.6, 1.6],
          emptyText: l.t('no_transactions'),
        ),
        ReportTable(
          title: l.t('tshirt_expenses'),
          headers: [l.t('date'), l.t('description'), l.t('quantity'), l.t('amount')],
          rows: [
            for (final e in expenses)
              [
                formatDate(e.date),
                e.description,
                e.quantity == null ? '' : '${e.quantity}',
                _m(ctx, e.amountPaise),
              ],
          ],
          footer: ['', l.t('total'), summary.quantity > 0 ? '${summary.quantity}' : '', _m(ctx, totals.expensePaise)],
          rightAligned: const {2, 3},
          columnFlex: const [1.3, 3.4, 1.2, 1.8],
          emptyText: l.t('no_transactions'),
        ),
      ],
    );
  }
}
