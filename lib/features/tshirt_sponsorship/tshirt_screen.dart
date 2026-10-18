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
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/sponsor.dart';

/// T-shirt sponsorship: sponsors' contributions and T-shirt expenses.
/// A separate fund - never mixed into the common mandal fund.
class TshirtScreen extends ConsumerWidget {
  const TshirtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final color = FundColors.of(Fund.tshirtSponsorship);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('tshirt')),
          backgroundColor: color.withValues(alpha: 0.15),
          actions: const [
            ReportButton(kind: ReportKind.tshirt),
            AppMenuButton(),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l.t('sponsors')),
              Tab(text: l.t('transactions')),
            ],
          ),
        ),
        floatingActionButton: Permissions.canAddEntry(role)
            ? FloatingActionButton.extended(
                onPressed: () => openEntryForm(context, Fund.tshirtSponsorship),
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
                  _SponsorsTab(),
                  _TshirtHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorsTab extends ConsumerStatefulWidget {
  const _SponsorsTab();

  @override
  ConsumerState<_SponsorsTab> createState() => _SponsorsTabState();
}

class _SponsorsTabState extends ConsumerState<_SponsorsTab> {
  DateTime? _from;
  DateTime? _to;

  Future<void> _addSponsor(List<Sponsor> existing) async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    await showEntityDialog(
      context,
      title: l.t('add_sponsor'),
      withContact: true,
      existingNames: existing.map((s) => s.name).toList(),
      onSubmit: (name, notes, contact, active) => ref
          .read(sponsorRepositoryProvider)
          .add(name: name, contact: contact, notes: notes, actor: actor),
    );
  }

  Future<void> _openSponsor(Sponsor sponsor, List<Sponsor> all) async {
    final l = ref.read(l10nProvider);
    final role = ref.read(roleProvider);
    final actor = ref.read(actorProvider);
    if (actor != null && Permissions.canManageGroupsAndSponsors(role)) {
      await showEntityDialog(
        context,
        title: l.t('edit_sponsor'),
        withContact: true,
        withActiveToggle: true,
        initialName: sponsor.name,
        initialNotes: sponsor.notes,
        initialContact: sponsor.contact,
        initialActive: sponsor.active,
        existingNames: all.map((s) => s.name).toList(),
        onSubmit: (name, notes, contact, active) async {
          await ref.read(sponsorRepositoryProvider).update(
                sponsor,
                name: name,
                contact: contact,
                notes: notes,
                active: active,
                actor: actor,
              );
          return sponsor.id;
        },
      );
      return;
    }
    // Read-only view for viewers.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sponsor.name),
        content: Text(
          [
            if ((sponsor.contact ?? '').isNotEmpty) '${l.t('contact_optional')}: ${sponsor.contact}',
            if ((sponsor.notes ?? '').isNotEmpty) sponsor.notes!,
          ].join('\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.t('close'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final sponsors = ref.watch(sponsorsProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.tshirtSponsorship));
    final color = FundColors.of(Fund.tshirtSponsorship);

    return AsyncValueView<List<Sponsor>>(
      value: sponsors,
      builder: (ss) => AsyncValueView<List<LedgerEntry>>(
        value: entries,
        builder: (all) {
          final scoped = LedgerFilter(from: _from, to: _to).apply(all);
          final summary = LedgerCalculator.tshirtSummary(scoped);
          final perSponsor = LedgerCalculator.sponsorSummaries(scoped, ss);
          final totals = summary.totals;

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              SummaryStrip(
                color: color,
                caption: (_from != null || _to != null) ? l.t('filtered_results') : null,
                items: [
                  SummaryLine(l.t('sponsorship_received'), totals.incomePaise),
                  SummaryLine(l.t('tshirt_expenses'), totals.expensePaise),
                  SummaryLine(l.t('balance'), totals.balancePaise,
                      emphasize: true, signColored: true),
                ],
              ),
              if (summary.quantity > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text('${l.t('tshirt_quantity')}: ${summary.quantity}'),
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
                          onPressed: () => _addSponsor(ss),
                          icon: const Icon(Icons.person_add_alt_outlined),
                          label: Text(l.t('add_sponsor')),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(l.t('sponsor_wise'), style: Theme.of(context).textTheme.titleSmall),
              ),
              if (perSponsor.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: EmptyState(message: l.t('no_sponsors'), icon: Icons.checkroom_outlined),
                )
              else
                for (final s in perSponsor)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(
                      s.sponsor.name,
                      style: s.sponsor.active
                          ? null
                          : TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                    subtitle: Text(
                      [
                        '${s.count} ${l.t('sponsorships_word')}',
                        if ((s.sponsor.contact ?? '').isNotEmpty) s.sponsor.contact!,
                      ].join(' • '),
                    ),
                    trailing: Text(
                      Money.format(s.totalPaise),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _openSponsor(s.sponsor, ss),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TshirtHistoryTab extends ConsumerWidget {
  const _TshirtHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final entries = ref.watch(fundEntriesProvider(Fund.tshirtSponsorship));
    final color = FundColors.of(Fund.tshirtSponsorship);

    return AsyncValueView<List<LedgerEntry>>(
      value: entries,
      builder: (all) => EntryListView(
        entries: all,
        summaryBuilder: (context, filtered, active) {
          final totals = LedgerCalculator.sum(filtered);
          return SummaryStrip(
            color: color,
            caption: active ? l.t('filtered_results') : null,
            items: [
              SummaryLine(l.t('sponsorship_received'), totals.incomePaise),
              SummaryLine(l.t('tshirt_expenses'), totals.expensePaise),
              SummaryLine(l.t('balance'), totals.balancePaise,
                  emphasize: true, signColored: true),
            ],
          );
        },
      ),
    );
  }
}
