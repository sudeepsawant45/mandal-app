import 'package:ganpati_mandal/domain/report_models.dart';

/// Plain-text summary suitable for WhatsApp / SMS. It carries the headline
/// figures only; the PDF holds the transaction detail.
class ReportText {
  ReportText._();

  static String summary(ReportData d) {
    final b = StringBuffer()
      ..writeln(d.mandalName)
      ..writeln(d.financialYearLine)
      ..writeln(d.title);
    if (d.subtitle != null && d.subtitle!.trim().isNotEmpty) {
      b.writeln(d.subtitle);
    }
    b
      ..writeln(d.periodLine)
      ..writeln();
    for (final row in d.summary) {
      b.writeln('${row.label}: ${row.value}');
    }
    b
      ..writeln()
      ..write(d.generatedLine);
    return b.toString();
  }
}
