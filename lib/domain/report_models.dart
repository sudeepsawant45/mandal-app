import 'package:ganpati_mandal/models/app_enums.dart';

class ReportSummaryRow {
  const ReportSummaryRow(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;
}

/// A table whose cells are already formatted strings, so the on-screen preview,
/// the PDF and the text summary all show identical numbers.
class ReportTable {
  const ReportTable({
    required this.title,
    required this.headers,
    required this.rows,
    this.footer = const [],
    this.rightAligned = const {},
    this.columnFlex,
    this.emptyText = '',
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  /// Optional totals row (same length as [headers]).
  final List<String> footer;
  final Set<int> rightAligned;
  final List<double>? columnFlex;

  /// Shown instead of the table body when [rows] is empty.
  final String emptyText;
}

/// Everything needed to render one report. Built by ReportBuilder (pure).
class ReportData {
  const ReportData({
    required this.kind,
    required this.title,
    required this.mandalName,
    required this.financialYearLine,
    required this.periodLine,
    required this.generatedLine,
    required this.pageWord,
    required this.fileName,
    required this.summary,
    required this.tables,
    required this.incomePaise,
    required this.expensePaise,
    this.subtitle,
  });

  final ReportKind kind;
  final String title;
  final String? subtitle;
  final String mandalName;

  /// e.g. "Financial year: 2026-27"
  final String financialYearLine;

  /// e.g. "Period: 01/09/2026 - 30/09/2026"
  final String periodLine;

  /// e.g. "Generated on: 16/10/2026 11:30"
  final String generatedLine;
  final String pageWord;

  /// Base name (no extension, no timestamp) for the exported file.
  final String fileName;

  final List<ReportSummaryRow> summary;
  final List<ReportTable> tables;

  final int incomePaise;
  final int expensePaise;
  int get balancePaise => incomePaise - expensePaise;
}
