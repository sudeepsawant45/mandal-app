import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/widgets/entity_dialog.dart';
import 'package:ganpati_mandal/core/widgets/fund_summary_card.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/ledger_calculator.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/ledger/entry_form_screen.dart';
import 'package:ganpati_mandal/features/ledger/entry_list_view.dart';
import 'package:ganpati_mandal/features/ledger/ledger_providers.dart';
import 'package:ganpati_mandal/features/reports/report_button.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';

/// One visarjan account: contributions, expenses and balance of a single
/// household/group, with its own detailed report.
class VisarjanGroupScreen extends ConsumerWidget {
  const VisarjanGroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final groups = ref.watch(visarjanGroupsProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.visarjan));
    final color = FundColors.of(Fund.visarjan);

    return AsyncValueView<List<VisarjanGroup>>(
      value: groups,
      builder: (gs) {
        final matches = gs.where((g) => g.id == groupId).toList();
        if (matches.isEmpty) {
          return Scaffold(appBar: AppBar(), body: EmptyState(message: l.t('not_found')));
        }
        final group = matches.first;

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              ReportButton(kind: ReportKind.visarjanGroup, groupId: group.id),
              if (Permissions.canManageGroupsAndSponsors(role))
                IconButton(
                  tooltip: l.t('edit'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final actor = ref.read(actorProvider);
                    if (actor == null) return;
                    await showEntityDialog(
                      context,
                      title: l.t('edit_group'),
                      initialName: group.name,
                      initialNotes: group.notes,
                      initialActive: group.active,
                      withActiveToggle: true,
                      existingNames: gs.map((g) => g.name).toList(),
                      onSubmit: (name, notes, contact, active) async {
                        await ref.read(visarjanRepositoryProvider).update(
                              group,
                              name: name,
                              notes: notes,
                              active: active,
                              actor: actor,
                            );
                        return group.id;
                      },
                    );
                  },
                ),
            ],
          ),
          floatingActionButton: Permissions.canAddEntry(role)
              ? FloatingActionButton.extended(
                  onPressed: () => openEntryForm(
                    context,
                    Fund.visarjan,
                    presetGroupId: group.id,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l.t('add_entry')),
                )
              : null,
          body: AsyncValueView<List<LedgerEntry>>(
            value: entries,
            builder: (all) {
              final own = all.where((e) => e.visarjanGroupId == group.id).toList();
              return EntryListView(
                entries: own,
                summaryBuilder: (context, filtered, active) {
                  // Totals of the filtered rows; with no filter this equals the
                  // group's account totals (contributions - expenses).
                  final totals = LedgerCalculator.sum(filtered);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SummaryStrip(
                        color: color,
                        caption: active ? l.t('filtered_results') : null,
                        items: [
                          SummaryLine(l.t('total_contributions'), totals.incomePaise),
                          SummaryLine(l.t('total_expenses'), totals.expensePaise),
                          SummaryLine(l.t('balance'), totals.balancePaise,
                              emphasize: true, signColored: true),
                        ],
                      ),
                      if ((group.notes ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Text(group.notes!),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
