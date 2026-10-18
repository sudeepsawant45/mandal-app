import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';

/// User-facing text for any thrown object, with the technical code appended.
String describeError(L10n l10n, Object error) {
  final ex = AppException.from(error);
  final base = l10n.t(ex.messageKey);
  final detail = ex.detail;
  return (detail == null || detail.isEmpty) ? base : '$base ($detail)';
}
