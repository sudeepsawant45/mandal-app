import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/widgets/entity_dialog.dart';
import 'package:ganpati_mandal/core/widgets/form_fields.dart';
import 'package:ganpati_mandal/core/widgets/fund_summary_card.dart';
import 'package:ganpati_mandal/core/widgets/read_only_banner.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/domain/ledger_filter.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/households/household_detail_screen.dart';
import 'package:ganpati_mandal/features/ledger/entry_form_screen.dart';
import 'package:ganpati_mandal/features/ledger/entry_list_view.dart';
import 'package:ganpati_mandal/features/ledger/ledger_providers.dart';
import 'package:ganpati_mandal/features/navigation/app_menu_button.dart';
import 'package:ganpati_mandal/features/reports/report_button.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// Household donations: household-wise summaries and the donation history.
class DonationsScreen extends ConsumerWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final color = FundColors.of(Fund.householdDonation);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('household_donations')),
          backgroundColor: color.withValues(alpha: 0.15),
          actions: const [
            ReportButton(kind: ReportKind.household),
            AppMenuButton(),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l.t('households')),
              Tab(text: l.t('transactions')),
            ],
          ),
        ),
        floatingActionButton: Permissions.canAddEntry(role)
            ? FloatingActionButton.extended(
                onPressed: () => openEntryForm(context, Fund.householdDonation),
                icon: const Icon(Icons.add),
                label: Text(l.t('add_donation')),
              )
            : null,
        body: Column(
          children: [
            if (Permissions.isReadOnly(role)) ReadOnlyBanner(l10n: l),
            const Expanded(
              child: TabBarView(
                children: [
                  _HouseholdsTab(),
                  _DonationsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Household-wise totals with search and a date-range filter.
class _HouseholdsTab extends ConsumerStatefulWidget {
  const _HouseholdsTab();

  @override
  ConsumerState<_HouseholdsTab> createState() => _HouseholdsTabState();
}

class _HouseholdsTabState extends ConsumerState<_HouseholdsTab> {
  String _query = '';
  DateTime? _from;
  DateTime? _to;

  Future<void> _addHousehold(List<Household> existing) async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    await showEntityDialog(
      context,
      title: l.t('add_household'),
      existingNames: existing.map((h) => h.name).toList(),
      onSubmit: (name, notes, contact, active) =>
          ref.read(householdRepositoryProvider).add(name: name, notes: notes, actor: actor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final households = ref.watch(householdsProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.householdDonation));

    return AsyncValueView<List<Household>>(
      value: households,
      builder: (hs) => AsyncValueView<List<LedgerEntry>>(
        value: entries,
        builder: (all) {
          final scoped = LedgerFilter(from: _from, to: _to).apply(all);
          final total = LedgerCalculator.sum(scoped).incomePaise;
          final q = _query.trim().toLowerCase();
          final summaries = LedgerCalculator.householdSummaries(scoped, hs)
              .where((s) => q.isEmpty || s.household.name.toLowerCase().contains(q))
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              SummaryStrip(
                color: FundColors.of(Fund.householdDonation),
                caption: (_from != null || _to != null) ? l.t('filtered_results') : null,
                items: [
                  SummaryLine(l.t('total_donations'), total, emphasize: true),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: l.t('search_household'),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                    DateRangeFilter(
                      l10n: l,
                      from: _from,
                      to: _to,
                      onChanged: (f, t) => setState(() {
                        _from = f;
                        _to = t;
                      }),
                    ),
                    if (Permissions.canManageHouseholds(role))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _addHousehold(hs),
                          icon: const Icon(Icons.add_home_work_outlined),
                          label: Text(l.t('add_household')),
                        ),
                      ),
                  ],
                ),
              ),
              if (summaries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: EmptyState(
                    message: hs.isEmpty ? l.t('no_households') : l.t('no_results'),
                    icon: Icons.home_work_outlined,
                  ),
                )
              else
                for (final s in summaries)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.home_outlined)),
                    title: Text(
                      s.household.name,
                      style: s.household.active
                          ? null
                          : TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                    subtitle: Text(
                      [
                        '${s.donationCount} ${l.t('donations_word')}',
                        if (s.lastDonation != null) formatDate(s.lastDonation!),
                        if (!s.household.active) l.t('archived'),
                      ].join(' • '),
                    ),
                    trailing: Text(
                      Money.format(s.totalPaise),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HouseholdDetailScreen(householdId: s.household.id),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// All household donations as individual transactions.
class _DonationsTab extends ConsumerWidget {
  const _DonationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.householdDonation));
    return AsyncValueView<List<LedgerEntry>>(
      value: entries,
      builder: (all) => EntryListView(
        entries: all,
        summaryBuilder: (context, filtered, active) => SummaryStrip(
          color: FundColors.of(Fund.householdDonation),
          caption: active ? l.t('filtered_results') : null,
          items: [
            SummaryLine(
              l.t('total_donations'),
              LedgerCalculator.sum(filtered).incomePaise,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}
