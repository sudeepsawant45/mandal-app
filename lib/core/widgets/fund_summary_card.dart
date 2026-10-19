import 'package:flutter/material.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';

class SummaryLine {
  const SummaryLine(
    this.label,
    this.paise, {
    this.emphasize = false,
    this.signColored = false,
    this.tone,
  });

  final String label;
  final int paise;
  final bool emphasize;

  /// Optional fixed colour for the amount (green income, red expense, blue balance).
  final Color? tone;

  /// Colours the value red when negative (used for balances).
  final bool signColored;
}

/// Card for one fund on the dashboard. Each fund has its own colour and its own
/// lines - funds are never added together here.
class FundSummaryCard extends StatelessWidget {
  const FundSummaryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
    this.openLabel,
    this.reportLabel,
    this.onOpen,
    this.onReport,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<SummaryLine> lines;
  final String? openLabel;
  final String? reportLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, color: color, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(line.label)),
                    Text(
                      Money.format(line.paise),
                      style: TextStyle(
                        fontWeight: line.emphasize ? FontWeight.bold : FontWeight.w500,
                        fontSize: line.emphasize ? 16 : 14,
                        color: line.signColored && line.paise < 0
                            ? FundColors.expense
                            : (line.tone ?? (line.emphasize ? color : null)),
                      ),
                    ),
                  ],
                ),
              ),
            if (onOpen != null || onReport != null)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  children: [
                    if (onReport != null)
                      TextButton.icon(
                        onPressed: onReport,
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text(reportLabel ?? ''),
                      ),
                    if (onOpen != null)
                      TextButton(onPressed: onOpen, child: Text(openLabel ?? '')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact row of labelled amounts (e.g. income | expense | balance).
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.items, this.color, this.caption});

  final List<SummaryLine> items;
  final Color? color;

  /// Small text above the numbers, e.g. "Filtered results".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  caption!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: accent),
                ),
              ),
            Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.labelMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Money.format(item.paise),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: item.emphasize ? FontWeight.bold : FontWeight.w600,
                            color: item.signColored && item.paise < 0
                                ? FundColors.expense
                                : (item.tone ?? (item.emphasize ? accent : null)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
