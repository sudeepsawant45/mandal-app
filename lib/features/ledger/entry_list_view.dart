import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/widgets/form_fields.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/ledger_filter.dart';
import 'package:ganpati_mandal/features/ledger/entry_details_sheet.dart';
import 'package:ganpati_mandal/features/ledger/entry_tile.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';

typedef EntrySummaryBuilder = Widget Function(
  BuildContext context,
  List<LedgerEntry> filtered,
  bool filterActive,
);

/// Transaction history with search, date-range, income/expense and (optionally)
/// visarjan-group filters. [entries] may include soft-deleted rows; they are
/// hidden unless an admin switches "show deleted" on.
class EntryListView extends ConsumerStatefulWidget {
  const EntryListView({
    super.key,
    required this.entries,
    this.summaryBuilder,
    this.groups,
    this.includeFund = false,
    this.bottomPadding = 88,
  });

  final List<LedgerEntry> entries;

  /// Builds the totals header from the entries that match the current filter.
  final EntrySummaryBuilder? summaryBuilder;

  /// When non-null a group dropdown filter is shown (visarjan history).
  final List<VisarjanGroup>? groups;
  final bool includeFund;
  final double bottomPadding;

  @override
  ConsumerState<EntryListView> createState() => _EntryListViewState();
}

class _EntryListViewState extends ConsumerState<EntryListView> {
  LedgerFilter _filter = const LedgerFilter();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final canSeeDeleted = role == AppRole.admin;
    final filter = _filter.copyWith(includeDeleted: canSeeDeleted && _filter.includeDeleted);
    final filtered = filter.apply(widget.entries);

    final top = <Widget>[
      if (widget.summaryBuilder != null)
        widget.summaryBuilder!(context, filtered, _filter.isActive),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l.t('search'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _filter = _filter.copyWith(query: ''));
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v)),
            ),
            const SizedBox(height: 8),
            DateRangeFilter(
              l10n: l,
              from: _filter.from,
              to: _filter.to,
              onChanged: (from, to) => setState(() {
                _filter = (from == null && to == null)
                    ? _filter.copyWith(clearDates: true)
                    : _filter.copyWith(from: from, to: to);
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<TxnType?>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment<TxnType?>(value: null, label: Text(l.t('all'))),
                      ButtonSegment<TxnType?>(
                        value: TxnType.income,
                        label: Text(l.t('income')),
                      ),
                      ButtonSegment<TxnType?>(
                        value: TxnType.expense,
                        label: Text(l.t('expense')),
                      ),
                    ],
                    selected: {_filter.type},
                    onSelectionChanged: (s) => setState(() {
                      final picked = s.first;
                      _filter = picked == null
                          ? _filter.copyWith(clearType: true)
                          : _filter.copyWith(type: picked);
                    }),
                  ),
                ),
              ],
            ),
            if (widget.groups != null) ...[
              const SizedBox(height: 8),
              AppDropdown<String?>(
                label: l.t('group'),
                value: _filter.groupId,
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(l.t('all_groups'))),
                  for (final g in widget.groups!)
                    DropdownMenuItem<String?>(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() {
                  _filter = v == null
                      ? _filter.copyWith(clearGroup: true)
                      : _filter.copyWith(groupId: v);
                }),
              ),
            ],
            if (canSeeDeleted)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.t('show_deleted')),
                value: _filter.includeDeleted,
                onChanged: (v) =>
                    setState(() => _filter = _filter.copyWith(includeDeleted: v)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
    ];

    final bodyCount = filtered.isEmpty ? 1 : filtered.length;
    return ListView.builder(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      itemCount: top.length + bodyCount,
      itemBuilder: (context, i) {
        if (i < top.length) return top[i];
        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: EmptyState(
              message: widget.entries.isEmpty ? l.t('no_transactions') : l.t('no_results'),
            ),
          );
        }
        final entry = filtered[i - top.length];
        return EntryTile(
          entry: entry,
          l10n: l,
          includeFund: widget.includeFund,
          onTap: () => showEntryDetails(context, entry),
        );
      },
    );
  }
}
