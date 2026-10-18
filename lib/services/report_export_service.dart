import 'dart:io';
import 'dart:typed_data';

import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/core/utils/text_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// What the operating system told us about a share attempt.
///
/// The app NEVER claims a report was "sent": Android does not reliably report
/// whether the chosen app (e.g. WhatsApp) actually delivered the file.
enum ShareOutcome {
  /// The platform reported the share as completed.
  completed,

  /// The user closed the share sheet without choosing a target.
  dismissed,

  /// The share sheet was opened but the platform cannot report the result.
  opened,
}

/// Writes generated report PDFs to disk and opens the Android share sheet.
class ReportExportService {
  const ReportExportService();

  /// Saves [bytes] as `<baseName>_<yyyyMMdd_HHmm>.pdf`. When [directory] is
  /// null the app's temporary directory (`<tmp>/reports`) is used. The file is
  /// re-read after writing; a short or missing file raises an [AppException]
  /// instead of being shared.
  Future<File> savePdf({
    required Uint8List bytes,
    required String baseName,
    required DateTime now,
    Directory? directory,
  }) async {
    if (bytes.isEmpty) throw const AppException('err_pdf_empty');
    try {
      final dir = directory ?? Directory('${(await getTemporaryDirectory()).path}/reports');
      await dir.create(recursive: true);
      final safe = safeFileFragment(baseName);
      final name = '${safe.isEmpty ? 'report' : safe}_${fileStamp(now)}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      if (!await file.exists() || await file.length() != bytes.length) {
        throw const AppException('err_file_write');
      }
      return file;
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('err_file_write', e.toString());
    }
  }

  /// Opens the Android share sheet for a real, existing PDF file.
  Future<ShareOutcome> sharePdf(
    File file, {
    required String subject,
    String? text,
  }) async {
    if (!await file.exists() || await file.length() == 0) {
      throw const AppException('err_file_missing');
    }
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: subject,
          text: text,
        ),
      );
      return _map(result.status);
    } catch (e) {
      throw AppException('err_share_failed', e.toString());
    }
  }

  /// Shares a plain-text summary through the share sheet.
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    if (text.trim().isEmpty) throw const AppException('err_share_failed', 'empty text');
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return _map(result.status);
    } catch (e) {
      throw AppException('err_share_failed', e.toString());
    }
  }

  ShareOutcome _map(ShareResultStatus status) {
    if (status == ShareResultStatus.success) return ShareOutcome.completed;
    if (status == ShareResultStatus.dismissed) return ShareOutcome.dismissed;
    return ShareOutcome.opened;
  }
}
