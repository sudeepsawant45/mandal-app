import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/widgets/form_fields.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/domain/report_builder.dart';
import 'package:ganpati_mandal/domain/report_models.dart';
import 'package:ganpati_mandal/domain/report_text.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/mandal_settings.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';
import 'package:ganpati_mandal/services/report_export_service.dart';

class _Inputs {
  const _Inputs({
    required this.entries,
    required this.households,
    required this.groups,
    required this.sponsors,
    required this.settings,
  });

  final List<LedgerEntry> entries;
  final List<Household> households;
  final List<VisarjanGroup> groups;
  final List<Sponsor> sponsors;
  final MandalSettings settings;
}

/// One report: period / group filters, an on-screen preview built from the
/// same [ReportData] that feeds the PDF, and the export / share actions.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.kind, this.groupId});

  final ReportKind kind;

  /// Preselected visarjan group (individual visarjan report only).
  final String? groupId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTime? _from;
  DateTime? _to;
  String? _groupId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  String get _titleKey {
    switch (widget.kind) {
      case ReportKind.household:
        return 'report_household';
      case ReportKind.commonFund:
        return 'report_common';
      case ReportKind.visarjanGroup:
        return 'report_visarjan_group';
      case ReportKind.visarjanCombined:
        return 'report_visarjan_combined';
      case ReportKind.tshirt:
        return 'report_tshirt';
    }
  }

  Fund get _fund {
    switch (widget.kind) {
      case ReportKind.household:
        return Fund.householdDonation;
      case ReportKind.commonFund:
        return Fund.commonMandal;
      case ReportKind.visarjanGroup:
      case ReportKind.visarjanCombined:
        return Fund.visarjan;
      case ReportKind.tshirt:
        return Fund.tshirtSponsorship;
    }
  }

  /// Null when the report cannot be built yet (individual visarjan report
  /// without a selected group).
  ReportData? _buildData(
    _Inputs i,
    L10n l10n, {
    String symbol = Money.rupeeSymbol,
  }) {
    final ctx = ReportContext(
      settings: i.settings,
      now: DateTime.now(),
      l10n: l10n,
      from: _from,
      to: _to,
      symbol: symbol,
    );
    switch (widget.kind) {
      case ReportKind.household:
        return ReportBuilder.household(
          entries: i.entries,
          households: i.households,
          ctx: ctx,
        );
      case ReportKind.commonFund:
        return ReportBuilder.commonFund(entries: i.entries, ctx: ctx);
      case ReportKind.visarjanGroup:
        final group = i.groups.where((g) => g.id == _groupId).firstOrNull;
        if (group == null) return null;
        return ReportBuilder.visarjanGroup(entries: i.entries, group: group, ctx: ctx);
      case ReportKind.visarjanCombined:
        return ReportBuilder.visarjanCombined(
          entries: i.entries,
          groups: i.groups,
          ctx: ctx,
        );
      case ReportKind.tshirt:
        return ReportBuilder.tshirt(
          entries: i.entries,
          sponsors: i.sponsors,
          ctx: ctx,
        );
    }
  }

  String _outcomeText(L10n l, ShareOutcome outcome) {
    switch (outcome) {
      case ShareOutcome.completed:
        return l.t('share_completed');
      case ShareOutcome.dismissed:
        return l.t('share_cancelled');
      case ShareOutcome.opened:
        return l.t('share_opened');
    }
  }

  /// Asks the server for this report's data (one fund, period-filtered, no
  /// deleted entries) so the PDF is built from the authoritative, freshly read
  /// records rather than from whatever the screen last polled.
  Future<_Inputs> _fetchFresh() async {
    final p = await ref.read(reportRepositoryProvider).fetch(
          widget.kind,
          groupId: widget.kind == ReportKind.visarjanGroup ? _groupId : null,
          from: _from,
          to: _to,
        );
    return _Inputs(
      entries: p.entries,
      households: p.households,
      groups: p.groups,
      sponsors: p.sponsors,
      settings: p.settings,
    );
  }

  Future<void> _exportPdf() async {
    if (_busy) return;
    final l = ref.read(l10nProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final inputs = await _fetchFresh();
      final fonts = await ref.read(pdfFontsProvider.future);
      // PDF text is always English (the pdf package cannot shape Devanagari
      // reliably) and uses "Rs." if the font lacks the rupee glyph.
      final pdfData = _buildData(
        inputs,
        L10n.en,
        symbol: fonts.hasRupeeGlyph ? Money.rupeeSymbol : 'Rs. ',
      );
      if (pdfData == null) throw const AppException('err_select_group');

      final bytes = await ref.read(pdfServiceProvider).build(pdfData, fonts);
      final export = ref.read(exportServiceProvider);
      final file = await export.savePdf(
        bytes: bytes,
        baseName: pdfData.fileName,
        now: DateTime.now(),
      );

      final textData = _buildData(inputs, l);
      final outcome = await export.sharePdf(
        file,
        subject: '${pdfData.mandalName} - ${pdfData.title}',
        text: textData == null ? null : ReportText.summary(textData),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('${_outcomeText(l, outcome)}\n${file.path.split('/').last}'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText(_Inputs shown) async {
    if (_busy) return;
    final l = ref.read(l10nProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (_buildData(shown, l) == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.t('err_select_group'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final data = _buildData(await _fetchFresh(), l);
      if (data == null) throw const AppException('err_select_group');
      final outcome = await ref.read(exportServiceProvider).shareText(
            ReportText.summary(data),
            subject: '${data.mandalName} - ${data.title}',
          );
      messenger.showSnackBar(SnackBar(content: Text(_outcomeText(l, outcome))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final color = FundColors.of(_fund);

    final entriesAv = ref.watch(allEntriesProvider);
    final settingsAv = ref.watch(settingsProvider);
    final householdsAv = ref.watch(householdsProvider);
    final groupsAv = ref.watch(visarjanGroupsProvider);
    final sponsorsAv = ref.watch(sponsorsProvider);

    final all = <AsyncValue<Object?>>[
      entriesAv,
      settingsAv,
      householdsAv,
      groupsAv,
      sponsorsAv,
    ];

    Widget body;
    final failed = all.where((a) => a.hasError).toList();
    if (failed.isNotEmpty) {
      body = ErrorState(error: failed.first.error!);
    } else if (all.any((a) => !a.hasValue)) {
      body = const LoadingState();
    } else {
      final inputs = _Inputs(
        entries: entriesAv.requireValue,
        households: householdsAv.requireValue,
        groups: groupsAv.requireValue,
        sponsors: sponsorsAv.requireValue,
        settings: settingsAv.requireValue,
      );
      body = _buildContent(context, l, role, inputs);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t(_titleKey)),
        backgroundColor: color.withValues(alpha: 0.15),
      ),
      body: body,
    );
  }

  Widget _buildContent(BuildContext context, L10n l, AppRole role, _Inputs inputs) {
    final data = _buildData(inputs, l);
    final canExport = Permissions.canExportReports(role);

    return ListView(
      padding: const EdgeInsets.all(12),
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
        if (widget.kind == ReportKind.visarjanGroup) ...[
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: l.t('group'),
            value: _groupId,
            items: [
              for (final g in inputs.groups)
                DropdownMenuItem<String>(value: g.id, child: Text(g.name)),
            ],
            onChanged: (v) => setState(() => _groupId = v),
          ),
        ],
        const SizedBox(height: 12),
        if (data == null)
          EmptyState(message: l.t('err_select_group'), icon: Icons.water_drop_outlined)
        else ...[
          _ReportPreview(data: data, l10n: l),
          const SizedBox(height: 16),
          if (canExport) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _exportPdf(),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(l.t('generate_pdf_share')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _shareText(inputs),
              icon: const Icon(Icons.share_outlined),
              label: Text(l.t('share_text_summary')),
            ),
            const SizedBox(height: 8),
            Text(l.t('pdf_english_note'), style: Theme.of(context).textTheme.bodySmall),
          ] else
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.t('viewer_no_export'))),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// On-screen rendering of a [ReportData].
class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.data, required this.l10n});

  final ReportData data;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.mandalName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(data.financialYearLine),
                const SizedBox(height: 6),
                Text(
                  data.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if ((data.subtitle ?? '').isNotEmpty)
                  Text(
                    data.subtitle!,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                Text(data.periodLine),
                const Divider(height: 20),
                for (final r in data.summary)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          r.label,
                          style: TextStyle(
                            fontWeight: r.emphasize ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          r.value,
                          style: TextStyle(
                            fontWeight: r.emphasize ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(data.generatedLine, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        for (final t in data.tables) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(t.title, style: theme.textTheme.titleSmall),
          ),
          _TableView(table: t),
        ],
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.table});

  final ReportTable table;

  @override
  Widget build(BuildContext context) {
    if (table.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          table.emptyText,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    const bold = TextStyle(fontWeight: FontWeight.bold);
    DataRow toRow(List<String> cells, {bool isBold = false}) => DataRow(
          cells: [
            for (var i = 0; i < table.headers.length; i++)
              DataCell(
                Text(i < cells.length ? cells[i] : '', style: isBold ? bold : null),
              ),
          ],
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          for (var i = 0; i < table.headers.length; i++)
            DataColumn(
              label: Text(table.headers[i], style: bold),
              numeric: table.rightAligned.contains(i),
            ),
        ],
        rows: [
          for (final r in table.rows) toRow(r),
          if (table.footer.isNotEmpty) toRow(table.footer, isBold: true),
        ],
      ),
    );
  }
}
