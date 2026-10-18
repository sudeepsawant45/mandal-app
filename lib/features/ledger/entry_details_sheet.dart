import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/widgets/confirm_dialog.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/ledger/entry_form_screen.dart';
import 'package:ganpati_mandal/features/ledger/ledger_labels.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// Opens the details / actions sheet for [entry]. Read-only for viewers.
Future<void> showEntryDetails(BuildContext context, LedgerEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EntryDetailsSheet(entry: entry),
  );
}

class _EntryDetailsSheet extends ConsumerStatefulWidget {
  const _EntryDetailsSheet({required this.entry});

  final LedgerEntry entry;

  @override
  ConsumerState<_EntryDetailsSheet> createState() => _EntryDetailsSheetState();
}

class _EntryDetailsSheetState extends ConsumerState<_EntryDetailsSheet> {
  bool _busy = false;

  Widget _row(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _delete(L10n l) async {
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    final ok = await confirmWith(
      context,
      l,
      title: l.t('delete_entry_title'),
      message: l.t('delete_entry_message'),
      confirmKey: 'delete',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(ledgerRepositoryProvider).softDelete(widget.entry, actor);
      messenger.showSnackBar(SnackBar(content: Text(l.t('entry_deleted'))));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(describeError(l, e))));
    }
  }

  Future<void> _restore(L10n l) async {
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(ledgerRepositoryProvider).restore(widget.entry, actor);
      messenger.showSnackBar(SnackBar(content: Text(l.t('entry_restored'))));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(describeError(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final actor = ref.watch(actorProvider);
    final e = widget.entry;
    final role = actor?.role;
    final canModify = actor != null &&
        Permissions.canModifyEntry(
          role: actor.role,
          uid: actor.uid,
          entry: e,
          now: DateTime.now(),
        );
    final canRestore =
        role != null && e.isDeleted && Permissions.canRestoreEntries(role);
    final canAdd = role != null && Permissions.canAddEntry(role);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${e.isIncome ? '+' : '-'}${Money.format(e.amountPaise)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _row(l.t('fund'), l.fund(e.fund)),
            _row(l.t('type'), entryTypeLabel(l, e.fund, e.type)),
            _row(l.t('date'), formatDate(e.date)),
            _row(l.t('household'), e.householdName),
            _row(l.t('group'), e.visarjanGroupName),
            _row(l.t('sponsor'), e.sponsorName),
            _row(l.t('contributor'), e.contributorName),
            _row(l.t('category'), l.category(e.category)),
            _row(l.t('description'), e.description),
            _row(l.t('method'), e.paymentMethod == null ? null : l.paymentMethod(e.paymentMethod)),
            _row(l.t('quantity'), e.quantity?.toString()),
            _row(l.t('note'), e.notes),
            const Divider(),
            _row(
              l.t('recorded_by'),
              '${e.createdByName} (${formatDateTime(e.createdAt)})',
            ),
            if (e.updatedAt != null)
              _row(
                l.t('edited_by'),
                '${e.updatedByName ?? ''} (${formatDateTime(e.updatedAt!)})',
              ),
            if (e.isDeleted)
              _row(
                l.t('deleted_by'),
                '${e.deletedByName ?? ''}${e.deletedAt == null ? '' : ' (${formatDateTime(e.deletedAt!)})'}',
              ),
            const SizedBox(height: 12),
            if (!canAdd)
              Text(l.t('viewer_read_only'), style: TextStyle(color: Theme.of(context).colorScheme.outline))
            else ...[
              if (!canModify && !e.isDeleted && !canRestore)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l.t('edit_not_allowed_hint'),
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              Row(
                children: [
                  if (canModify && !e.isDeleted)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () {
                                final navigator = Navigator.of(context);
                                navigator.pop();
                                navigator.push(
                                  MaterialPageRoute<bool>(
                                    builder: (_) => EntryFormScreen(fund: e.fund, existing: e),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l.t('edit')),
                      ),
                    ),
                  if (canModify && !e.isDeleted) const SizedBox(width: 12),
                  if (canModify && !e.isDeleted)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: _busy ? null : () => _delete(l),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l.t('delete')),
                      ),
                    ),
                  if (canRestore)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _restore(l),
                        icon: const Icon(Icons.restore),
                        label: Text(l.t('restore')),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
