import 'package:flutter/material.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';
import 'package:ganpati_mandal/features/ledger/ledger_labels.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// One transaction row. Deleted entries are struck through and greyed.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.l10n,
    this.onTap,
    this.includeFund = false,
  });

  final LedgerEntry entry;
  final L10n l10n;
  final VoidCallback? onTap;
  final bool includeFund;

  @override
  Widget build(BuildContext context) {
    final deleted = entry.isDeleted;
    final color = deleted
        ? Theme.of(context).colorScheme.outline
        : (entry.isIncome ? FundColors.income : FundColors.expense);
    final sign = entry.isIncome ? '+' : '-';
    final titleStyle = TextStyle(
      decoration: deleted ? TextDecoration.lineThrough : null,
      color: deleted ? Theme.of(context).colorScheme.outline : null,
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: IconBadge(
          icon: entry.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 40,
        ),
        title: Text(
          entryTitle(l10n, entry),
          style: titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          entrySubtitle(l10n, entry, includeFund: includeFund) +
              (deleted ? ' • ${l10n.t('deleted')}' : ''),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '$sign${Money.format(entry.amountPaise)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            decoration: deleted ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
