import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';
import 'package:ganpati_mandal/core/widgets/fund_summary_card.dart';
import 'package:ganpati_mandal/core/widgets/read_only_banner.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/domain/ledger_filter.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/ledger/entry_details_sheet.dart';
import 'package:ganpati_mandal/features/ledger/entry_tile.dart';
import 'package:ganpati_mandal/features/audit/audit_screen.dart';
import 'package:ganpati_mandal/features/profile/profile_screen.dart';
import 'package:ganpati_mandal/features/users/users_screen.dart';
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

    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings?.mandalName ?? l.t('app_name')),
        actions: [
          IconButton(
            tooltip: l.t('reports'),
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportsHubScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              ),
              child: Semantics(
                label: l.t('my_profile'),
                button: true,
                child: InitialsAvatar(name: user?.label ?? '', radius: 18),
              ),
            ),
          ),
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
          void push(Widget w) =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

          Widget shortcut(IconData icon, Color color, String label, VoidCallback onTap) {
            return InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconBadge(icon: icon, color: color, size: 52),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }

          final shortcuts = <Widget>[
            shortcut(FundColors.iconOf(Fund.householdDonation), FundColors.of(Fund.householdDonation),
                l.t('nav_donations'), () => goToTab(1)),
            shortcut(FundColors.iconOf(Fund.commonMandal), FundColors.of(Fund.commonMandal),
                l.t('nav_common'), () => goToTab(2)),
            shortcut(FundColors.iconOf(Fund.visarjan), FundColors.of(Fund.visarjan),
                l.t('nav_visarjan'), () => goToTab(3)),
            shortcut(FundColors.iconOf(Fund.tshirtSponsorship), FundColors.of(Fund.tshirtSponsorship),
                l.t('nav_tshirt'), () => goToTab(4)),
            shortcut(Icons.assessment_outlined, AppTheme.royalBlue, l.t('reports'),
                () => push(const ReportsHubScreen())),
            if (Permissions.canManageUsers(role))
              shortcut(Icons.people_outline, AppTheme.royalBlue, l.t('users'),
                  () => push(const UsersScreen())),
            if (Permissions.canViewAudit(role))
              shortcut(Icons.history, AppTheme.royalBlue, l.t('audit_log'),
                  () => push(const AuditScreen())),
            if (Permissions.canConfigureSettings(role))
              shortcut(Icons.tune, AppTheme.royalBlue, l.t('mandal_settings'),
                  () => push(const SettingsScreen())),
          ];

          Widget heroTile(String label, int paise, Color color, IconData icon) => Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Money.format(paise),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              );

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                decoration: const BoxDecoration(
                  color: AppTheme.royalBlue,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.t('welcome_back')}, ${user?.label ?? ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (settings != null)
                      Text(
                        '${l.t('financial_year')}: ${settings.financialYear}',
                        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      l.t('common_fund_overview'),
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        heroTile(l.t('income'), common.incomePaise, FundColors.income,
                            Icons.south_west),
                        const SizedBox(width: 8),
                        heroTile(l.t('expense'), common.expensePaise, FundColors.expense,
                            Icons.north_east),
                        const SizedBox(width: 8),
                        heroTile(
                          l.t('balance'),
                          common.balancePaise,
                          common.balancePaise < 0 ? FundColors.expense : FundColors.balance,
                          Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SectionHeader(l.t('quick_access')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    // Wrap + fixed-width tiles (not a fixed-height grid) so two-line
                    // Marathi labels and large system font sizes cannot overflow.
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final tileWidth = box.maxWidth / 4;
                        return Wrap(
                          children: [
                            for (final s in shortcuts) SizedBox(width: tileWidth, child: s),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
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
                    SummaryLine(l.t('income'), common.incomePaise, tone: FundColors.income),
                    SummaryLine(l.t('expense'), common.expensePaise, tone: FundColors.expense),
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
                    SummaryLine(l.t('total_contributions'), visarjan.incomePaise, tone: FundColors.income),
                    SummaryLine(l.t('total_expenses'), visarjan.expensePaise, tone: FundColors.expense),
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
                    SummaryLine(l.t('sponsorship_received'), tshirt.incomePaise, tone: FundColors.income),
                    SummaryLine(l.t('tshirt_expenses'), tshirt.expensePaise, tone: FundColors.expense),
                    SummaryLine(l.t('balance'), tshirt.balancePaise,
                        emphasize: true, signColored: true),
                  ],
                  openLabel: l.t('open'),
                  reportLabel: l.t('report'),
                  onOpen: () => goToTab(4),
                  onReport: () => openReport(context, ReportKind.tshirt),
                ),
              ),
              SectionHeader(l.t('recent_transactions')),
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
