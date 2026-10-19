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
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// One household: its donations (each a separate transaction) and running total.
class HouseholdDetailScreen extends ConsumerWidget {
  const HouseholdDetailScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final households = ref.watch(householdsProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.householdDonation));

    return AsyncValueView<List<Household>>(
      value: households,
      builder: (hs) {
        final matches = hs.where((h) => h.id == householdId).toList();
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(message: l.t('not_found')),
          );
        }
        final household = matches.first;
        final color = FundColors.of(Fund.householdDonation);

        return Scaffold(
          appBar: AppBar(
            title: Text(household.name),
            actions: [
              if (Permissions.canManageHouseholds(role))
                IconButton(
                  tooltip: l.t('edit'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final actor = ref.read(actorProvider);
                    if (actor == null) return;
                    await showEntityDialog(
                      context,
                      title: l.t('edit_household'),
                      initialName: household.name,
                      initialNotes: household.notes,
                      initialActive: household.active,
                      withActiveToggle: true,
                      existingNames: hs.map((h) => h.name).toList(),
                      onSubmit: (name, notes, contact, active) async {
                        await ref.read(householdRepositoryProvider).update(
                              household,
                              name: name,
                              notes: notes,
                              active: active,
                              actor: actor,
                            );
                        return household.id;
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
                    Fund.householdDonation,
                    presetHouseholdId: household.id,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l.t('add_donation')),
                )
              : null,
          body: AsyncValueView<List<LedgerEntry>>(
            value: entries,
            builder: (all) {
              final own = all.where((e) => e.householdId == household.id).toList();
              return EntryListView(
                entries: own,
                summaryBuilder: (context, filtered, active) {
                  final live = filtered.where((e) => !e.isDeleted).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SummaryStrip(
                        color: color,
                        caption: active ? l.t('filtered_results') : null,
                        items: [
                          SummaryLine(
                            l.t('total_donations'),
                            LedgerCalculator.sum(live).incomePaise,
                            emphasize: true,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Text('${l.t('donation_count')}: ${live.length}'),
                      ),
                      if ((household.notes ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Text(household.notes!),
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
