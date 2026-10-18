import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/widgets/entity_dialog.dart';
import 'package:ganpati_mandal/core/widgets/form_fields.dart';
import 'package:ganpati_mandal/core/widgets/fund_summary_card.dart';
import 'package:ganpati_mandal/core/widgets/read_only_banner.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/domain/ledger_filter.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/ledger/entry_form_screen.dart';
import 'package:ganpati_mandal/features/ledger/entry_list_view.dart';
import 'package:ganpati_mandal/features/ledger/ledger_providers.dart';
import 'package:ganpati_mandal/features/navigation/app_menu_button.dart';
import 'package:ganpati_mandal/features/reports/report_button.dart';
import 'package:ganpati_mandal/features/visarjan/visarjan_group_screen.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';

/// Visarjan: one separate account per household/group, plus the combined view.
/// Entirely separate from the common mandal fund.
class VisarjanScreen extends ConsumerWidget {
  const VisarjanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final color = FundColors.of(Fund.visarjan);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('visarjan')),
          backgroundColor: color.withValues(alpha: 0.15),
          actions: const [
            // Combined report for all visarjan groups; the individual group
            // report is on each group's own screen.
            ReportButton(kind: ReportKind.visarjanCombined),
            AppMenuButton(),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l.t('groups')),
              Tab(text: l.t('transactions')),
            ],
          ),
        ),
        floatingActionButton: Permissions.canAddEntry(role)
            ? FloatingActionButton.extended(
                onPressed: () => openEntryForm(context, Fund.visarjan),
                icon: const Icon(Icons.add),
                label: Text(l.t('add_entry')),
              )
            : null,
        body: Column(
          children: [
            if (Permissions.isReadOnly(role)) ReadOnlyBanner(l10n: l),
            const Expanded(
              child: TabBarView(
                children: [
                  _GroupsTab(),
                  _HistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsTab extends ConsumerStatefulWidget {
  const _GroupsTab();

  @override
  ConsumerState<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<_GroupsTab> {
  DateTime? _from;
  DateTime? _to;

  Future<void> _addGroup(List<VisarjanGroup> existing) async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    await showEntityDialog(
      context,
      title: l.t('add_group'),
      existingNames: existing.map((g) => g.name).toList(),
      onSubmit: (name, notes, contact, active) =>
          ref.read(visarjanRepositoryProvider).add(name: name, notes: notes, actor: actor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final groups = ref.watch(visarjanGroupsProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.visarjan));
    final color = FundColors.of(Fund.visarjan);

    return AsyncValueView<List<VisarjanGroup>>(
      value: groups,
      builder: (gs) => AsyncValueView<List<LedgerEntry>>(
        value: entries,
        builder: (all) {
          final scoped = LedgerFilter(from: _from, to: _to).apply(all);
          final combined = LedgerCalculator.visarjanCombinedTotals(scoped);
          final summaries = LedgerCalculator.visarjanGroupSummaries(scoped, gs);

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              SummaryStrip(
                color: color,
                caption: l.t('all_visarjan_combined') +
                    ((_from != null || _to != null) ? ' • ${l.t('filtered_results')}' : ''),
                items: [
                  SummaryLine(l.t('total_contributions'), combined.incomePaise),
                  SummaryLine(l.t('total_expenses'), combined.expensePaise),
                  SummaryLine(l.t('balance'), combined.balancePaise,
                      emphasize: true, signColored: true),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    DateRangeFilter(
                      l10n: l,
                      from: _from,
                      to: _to,
                      onChanged: (f, t) => setState(() {
                        _from = f;
                        _to = t;
                      }),
                    ),
                    if (Permissions.canManageGroupsAndSponsors(role))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _addGroup(gs),
                          icon: const Icon(Icons.group_add_outlined),
                          label: Text(l.t('add_group')),
                        ),
                      ),
                  ],
                ),
              ),
              if (summaries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: EmptyState(message: l.t('no_groups'), icon: Icons.water_drop_outlined),
                )
              else
                for (final s in summaries)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(Icons.water_drop_outlined, color: color),
                      ),
                      title: Text(
                        s.group.name,
                        style: s.group.active
                            ? null
                            : TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                      subtitle: Text(
                        '${l.t('total_contributions')}: ${Money.format(s.totals.incomePaise)}\n'
                        '${l.t('total_expenses')}: ${Money.format(s.totals.expensePaise)}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(l.t('balance'), style: Theme.of(context).textTheme.labelSmall),
                          Text(
                            Money.format(s.totals.balancePaise),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.totals.balancePaise < 0 ? FundColors.expense : null,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VisarjanGroupScreen(groupId: s.group.id),
                        ),
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

/// Complete visarjan transaction history with group, date, type and text filters.
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final groups = ref.watch(visarjanGroupsProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.visarjan));
    final color = FundColors.of(Fund.visarjan);

    return AsyncValueView<List<VisarjanGroup>>(
      value: groups,
      builder: (gs) => AsyncValueView<List<LedgerEntry>>(
        value: entries,
        builder: (all) => EntryListView(
          entries: all,
          groups: gs,
          summaryBuilder: (context, filtered, active) {
            final totals = LedgerCalculator.sum(filtered);
            return SummaryStrip(
              color: color,
              caption: active ? l.t('filtered_results') : null,
              items: [
                SummaryLine(l.t('total_contributions'), totals.incomePaise),
                SummaryLine(l.t('total_expenses'), totals.expensePaise),
                SummaryLine(l.t('balance'), totals.balancePaise,
                    emphasize: true, signColored: true),
              ],
            );
          },
        ),
      ),
    );
  }
}
