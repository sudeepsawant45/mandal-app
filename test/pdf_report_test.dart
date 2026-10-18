import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/domain/report_builder.dart';
import 'package:ganpati_mandal/domain/report_models.dart';
import 'package:ganpati_mandal/services/pdf_fonts.dart';
import 'package:ganpati_mandal/services/pdf_report_service.dart';
import 'package:ganpati_mandal/services/report_export_service.dart';

import 'helpers/factories.dart';

bool isPdf(Uint8List b) =>
    b.length > 5 && String.fromCharCodes(b.sublist(0, 5)) == '%PDF-';

ReportData sample({String symbol = 'Rs. '}) => ReportBuilder.household(
      entries: [
        for (var i = 0; i < 5; i++) donation('d$i', 'h1', 100000 + i),
      ],
      households: kHouseholds,
      ctx: ReportContext(settings: kSettings, now: kNow, l10n: L10n.en, symbol: symbol),
    );

void main() {
  const service = PdfReportService();

  test('builds a valid PDF with fallback fonts', () async {
    final bytes = await service.build(sample(), PdfFonts.fallback());
    expect(isPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(1000));
  });

  test('builds a valid PDF with the bundled Mukta fonts (rupee sign)', () async {
    final regular = File('assets/fonts/Mukta-Regular.ttf').readAsBytesSync();
    final bold = File('assets/fonts/Mukta-Bold.ttf').readAsBytesSync();
    final fonts = PdfFonts.fromBytes(regular, bold);
    expect(fonts.hasRupeeGlyph, isTrue);
    final bytes = await service.build(sample(symbol: '₹'), fonts);
    expect(isPdf(bytes), isTrue);
  });

  test('every report kind renders, including empty ones', () async {
    final c = ReportContext(settings: kSettings, now: kNow, l10n: L10n.en, symbol: 'Rs. ');
    final reports = [
      ReportBuilder.household(entries: const [], households: kHouseholds, ctx: c),
      ReportBuilder.commonFund(entries: const [], ctx: c),
      ReportBuilder.visarjanGroup(entries: const [], group: kGroups[0], ctx: c),
      ReportBuilder.visarjanCombined(entries: const [], groups: kGroups, ctx: c),
      ReportBuilder.tshirt(entries: const [], sponsors: kSponsors, ctx: c),
    ];
    for (final r in reports) {
      final bytes = await service.build(r, PdfFonts.fallback());
      expect(isPdf(bytes), isTrue, reason: r.title);
    }
  });

  test('a long ledger (well over 20 pages) does not hit the page limit', () async {
    final many = [for (var i = 0; i < 1500; i++) commonIncome('c$i', 100 + i)];
    final data = ReportBuilder.commonFund(
      entries: many,
      ctx: ReportContext(settings: kSettings, now: kNow, l10n: L10n.en, symbol: 'Rs. '),
    );
    final bytes = await service.build(data, PdfFonts.fallback());
    expect(isPdf(bytes), isTrue);
  });

  group('ReportExportService.savePdf', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('mandal_pdf_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('writes a real, non-empty, correctly named file', () async {
      final bytes = await service.build(sample(), PdfFonts.fallback());
      final file = await const ReportExportService()
          .savePdf(bytes: bytes, baseName: 'household_donations', now: kNow, directory: tmp);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), bytes.length);
      expect(file.path, endsWith('household_donations_20260920_1200.pdf'));
      expect(isPdf(file.readAsBytesSync()), isTrue);
    });

    test('unsafe characters in the base name are sanitised', () async {
      final file = await const ReportExportService().savePdf(
        bytes: Uint8List.fromList([1, 2, 3]),
        baseName: '../evil/na me?',
        now: kNow,
        directory: tmp,
      );
      expect(file.parent.path, tmp.path);
      expect(file.uri.pathSegments.last, isNot(contains('..')));
    });

    test('empty bytes are refused instead of producing an empty file', () async {
      expect(
        () => const ReportExportService()
            .savePdf(bytes: Uint8List(0), baseName: 'x', now: kNow, directory: tmp),
        throwsA(isA<AppException>()),
      );
      expect(tmp.listSync(), isEmpty);
    });

    test('sharePdf refuses a missing file (never fakes success)', () async {
      expect(
        () => const ReportExportService().sharePdf(File('${tmp.path}/nope.pdf'), subject: 's'),
        throwsA(isA<AppException>()),
      );
    });
  });
}
