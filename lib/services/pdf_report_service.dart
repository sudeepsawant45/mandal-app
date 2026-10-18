import 'dart:typed_data';

import 'package:ganpati_mandal/domain/report_models.dart';
import 'package:ganpati_mandal/services/pdf_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders a [ReportData] to PDF bytes (A4). Pure: no file or UI access.
class PdfReportService {
  const PdfReportService();

  Future<Uint8List> build(ReportData data, PdfFonts fonts) async {
    final doc = pw.Document(
      title: '${data.mandalName} - ${data.title}',
      author: data.mandalName,
      creator: 'Ganpati Mandal app',
    );
    final theme = pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);

    final small = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);

    doc.addPage(
      pw.MultiPage(
        // The default cap is 20 pages; a full-year ledger with hundreds of
        // transactions must not fail with TooManyPagesException.
        maxPages: 1000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
          theme: theme,
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text('${data.mandalName} - ${data.title}', style: small),
              ),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(data.generatedLine, style: small),
              pw.Text('${data.pageWord} ${ctx.pageNumber}/${ctx.pagesCount}', style: small),
            ],
          ),
        ),
        build: (ctx) => [
          _titleBlock(data),
          pw.SizedBox(height: 10),
          _summaryBlock(data),
          for (final t in data.tables) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              t.title,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            _tableBlock(t),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _titleBlock(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          d.mandalName,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(d.financialYearLine, style: pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Text(
          d.title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        if (d.subtitle != null && d.subtitle!.trim().isNotEmpty)
          pw.Text(
            d.subtitle!,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        pw.SizedBox(height: 2),
        pw.Text(d.periodLine, style: pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _summaryBlock(ReportData d) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          for (final r in d.summary)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    r.label,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: r.emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  ),
                  pw.Text(
                    r.value,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: r.emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _tableBlock(ReportTable t) {
    if (t.rows.isEmpty) {
      return pw.Text(
        t.emptyText,
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      );
    }

    pw.TableRow buildRow(
      List<String> cells, {
      bool header = false,
      bool footer = false,
    }) {
      return pw.TableRow(
        repeat: header,
        decoration: header
            ? pw.BoxDecoration(color: PdfColors.grey300)
            : footer
                ? pw.BoxDecoration(color: PdfColors.grey200)
                : null,
        children: [
          for (var i = 0; i < t.headers.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text(
                i < cells.length ? cells[i] : '',
                textAlign: t.rightAligned.contains(i) ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: (header || footer) ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
        ],
      );
    }

    final flex = t.columnFlex;
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      columnWidths: flex == null || flex.length != t.headers.length
          ? null
          : {
              for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i]),
            },
      children: [
        buildRow(t.headers, header: true),
        for (final r in t.rows) buildRow(r),
        if (t.footer.isNotEmpty) buildRow(t.footer, footer: true),
      ],
    );
  }
}
