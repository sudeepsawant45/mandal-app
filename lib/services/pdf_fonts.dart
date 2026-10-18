import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fonts used inside generated PDFs.
///
/// The bundled Mukta fonts (SIL Open Font License) contain the rupee sign and
/// Devanagari glyphs. If the asset fonts cannot be loaded the PDF falls back to
/// built-in Helvetica, which has NO rupee glyph; [hasRupeeGlyph] is then false
/// and report text must use "Rs." instead (ReportContext.symbol).
///
/// Known limitation: the `pdf` package does not do complex-script shaping, so
/// Devanagari text (e.g. Marathi names typed by users) is drawn glyph by glyph
/// and conjuncts/vowel signs may look wrong. Report labels in PDFs are
/// therefore always English. Verify with the checklist in README.
class PdfFonts {
  const PdfFonts({
    required this.regular,
    required this.bold,
    required this.hasRupeeGlyph,
  });

  final pw.Font regular;
  final pw.Font bold;
  final bool hasRupeeGlyph;

  /// Built-in Helvetica (no ₹ / Devanagari glyphs).
  factory PdfFonts.fallback() => PdfFonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        hasRupeeGlyph: false,
      );

  /// From raw TTF bytes (used by tests and by [loadFromAssets]).
  factory PdfFonts.fromBytes(Uint8List regular, Uint8List bold) => PdfFonts(
        regular: pw.Font.ttf(ByteData.sublistView(regular)),
        bold: pw.Font.ttf(ByteData.sublistView(bold)),
        hasRupeeGlyph: true,
      );

  /// Loads the bundled Mukta fonts; falls back to Helvetica if they are missing.
  static Future<PdfFonts> loadFromAssets() async {
    try {
      final regular = await rootBundle.load(AppConstants.fontRegularAsset);
      final bold = await rootBundle.load(AppConstants.fontBoldAsset);
      return PdfFonts(
        regular: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
        hasRupeeGlyph: true,
      );
    } catch (_) {
      return PdfFonts.fallback();
    }
  }
}
