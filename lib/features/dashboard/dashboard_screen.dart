import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/widgets/fund_summary_card.dart';
import 'package:ganpati_mandal/core/widgets/read_only_banner.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/domain/ledger_filter.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/ledger/entry_details_sheet.dart';
import 'package:ganpati_mandal/features/ledger/entry_tile.dart';
import 'package:ganpati_mandal/features/navigation/app_menu_button.dart';
import 'package:ganpati_mandal/features/reports/report_button.dart';
import 'package:ganpati_mandal/features/reports/reports_hub_screen.dart';
import 'package:ganpati_mandal/features/settings/settings_screen.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// Overview of the four funds. Each fund is shown on its own card with its own
/// numbers; they are deliberately NOT added into one "bank balance".
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final entries = ref.watch(allEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings?.mandalName ?? l.t('app_name')),
            if (settings != null)
              Text(
                '${l.t('financial_year')}: ${settings.financialYear}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.t('reports'),
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportsHubScreen()),
            ),
          ),
          const AppMenuButton(),
        ],
      ),
      body: AsyncValueView<List<LedgerEntry>>(
        value: entries,
        builder: (all) {
          final byFund = LedgerCalculator.totalsByFund(all);
          final household = byFund[Fund.householdDonation]!;
          final common = byFund[Fund.commonMandal]!;
          final visarjan = byFund[Fund.visarjan]!;
          final tshirt = byFund[Fund.tshirtSponsorship]!;

          final recent = const LedgerFilter().apply(all).take(AppConstants.recentCount).toList();

          void goToTab(int i) => ref.read(homeTabProvider.notifier).state = i;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (Permissions.isReadOnly(role)) ReadOnlyBanner(l10n: l),
              if (settings != null &&
                  !settings.configured &&
                  Permissions.canConfigureSettings(role))
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l.t('settings_not_configured')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  l.t('funds_separate_note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: FundSummaryCard(
                  title: l.fund(Fund.householdDonation),
                  icon: FundColors.iconOf(Fund.householdDonation),
                  color: FundColors.of(Fund.householdDonation),
                  lines: [
                    SummaryLine(l.t('total_donations'), household.incomePaise, emphasize: true),
                  ],
                  openLabel: l.t('open'),
                  reportLabel: l.t('report'),
                  onOpen: () => goToTab(1),
                  onReport: () => openReport(context, ReportKind.household),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: FundSummaryCard(
                  title: l.fund(Fund.commonMandal),
                  icon: FundColors.iconOf(Fund.commonMandal),
                  color: FundColors.of(Fund.commonMandal),
                  lines: [
                    SummaryLine(l.t('income'), common.incomePaise),
                    SummaryLine(l.t('expense'), common.expensePaise),
                    SummaryLine(l.t('balance'), common.balancePaise,
                        emphasize: true, signColored: true),
                  ],
                  openLabel: l.t('open'),
                  reportLabel: l.t('report'),
                  onOpen: () => goToTab(2),
                  onReport: () => openReport(context, ReportKind.commonFund),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: FundSummaryCard(
                  title: l.fund(Fund.visarjan),
                  icon: FundColors.iconOf(Fund.visarjan),
                  color: FundColors.of(Fund.visarjan),
                  lines: [
                    SummaryLine(l.t('total_contributions'), visarjan.incomePaise),
                    SummaryLine(l.t('total_expenses'), visarjan.expensePaise),
                    SummaryLine(l.t('balance'), visarjan.balancePaise,
                        emphasize: true, signColored: true),
                  ],
                  openLabel: l.t('open'),
                  reportLabel: l.t('report'),
                  onOpen: () => goToTab(3),
                  onReport: () => openReport(context, ReportKind.visarjanCombined),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: FundSummaryCard(
                  title: l.fund(Fund.tshirtSponsorship),
                  icon: FundColors.iconOf(Fund.tshirtSponsorship),
                  color: FundColors.of(Fund.tshirtSponsorship),
                  lines: [
                    SummaryLine(l.t('sponsorship_received'), tshirt.incomePaise),
                    SummaryLine(l.t('tshirt_expenses'), tshirt.expensePaise),
                    SummaryLine(l.t('balance'), tshirt.balancePaise,
                        emphasize: true, signColored: true),
                  ],
                  openLabel: l.t('open'),
                  reportLabel: l.t('report'),
                  onOpen: () => goToTab(4),
                  onReport: () => openReport(context, ReportKind.tshirt),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l.t('recent_transactions'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(message: l.t('no_transactions')),
                )
              else
                for (final e in recent)
                  EntryTile(
                    entry: e,
                    l10n: l,
                    includeFund: true,
                    onTap: () => showEntryDetails(context, e),
                  ),
            ],
          );
        },
      ),
    );
  }
}
