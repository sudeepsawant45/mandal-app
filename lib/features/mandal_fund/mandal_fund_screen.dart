import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/widgets/fund_summary_card.dart';
import 'package:ganpati_mandal/core/widgets/read_only_banner.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/ledger/entry_form_screen.dart';
import 'package:ganpati_mandal/features/ledger/entry_list_view.dart';
import 'package:ganpati_mandal/features/ledger/ledger_providers.dart';
import 'package:ganpati_mandal/features/navigation/app_menu_button.dart';
import 'package:ganpati_mandal/features/reports/report_button.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// The common mandal fund ledger: income and expenses of the mandal itself
/// (separate from household donations, visarjan accounts and T-shirt funds).
class MandalFundScreen extends ConsumerWidget {
  const MandalFundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.commonMandal));
    final color = FundColors.of(Fund.commonMandal);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('common_fund')),
        backgroundColor: color.withValues(alpha: 0.15),
        actions: const [
          ReportButton(kind: ReportKind.commonFund),
          AppMenuButton(),
        ],
      ),
      floatingActionButton: Permissions.canAddEntry(role)
          ? FloatingActionButton.extended(
              onPressed: () => openEntryForm(context, Fund.commonMandal),
              icon: const Icon(Icons.add),
              label: Text(l.t('add_entry')),
            )
          : null,
      body: Column(
        children: [
          if (Permissions.isReadOnly(role)) ReadOnlyBanner(l10n: l),
          Expanded(
            child: AsyncValueView<List<LedgerEntry>>(
              value: entries,
              builder: (all) => EntryListView(
                entries: all,
                summaryBuilder: (context, filtered, active) {
                  final totals = LedgerCalculator.sum(filtered);
                  return SummaryStrip(
                    color: color,
                    caption: active ? l.t('filtered_results') : null,
                    items: [
                      SummaryLine(l.t('income'), totals.incomePaise),
                      SummaryLine(l.t('expense'), totals.expensePaise),
                      SummaryLine(l.t('balance'), totals.balancePaise,
                          emphasize: true, signColored: true),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
