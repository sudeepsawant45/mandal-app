import 'package:ganpati_mandal/core/l10n/l10n_en.dart';
import 'package:ganpati_mandal/core/l10n/l10n_mr.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

/// Minimal in-app localisation (Marathi default, English alternative).
/// A missing Marathi key falls back to English, a missing English key to the
/// key itself, so a UI string can never crash the app.
class L10n {
  const L10n(this.lang);

  final String lang;

  static const en = L10n('en');
  static const mr = L10n('mr');

  bool get isMarathi => lang == 'mr';

  L10n get toggled => isMarathi ? en : mr;

  String t(String key) => (isMarathi ? kMr[key] : kEn[key]) ?? kEn[key] ?? key;

  String category(String key) => t('cat_$key');

  String paymentMethod(String? value) => value == null ? '' : t('pm_$value');

  String fund(Fund f) => t('fund_${f.value}');

  String role(AppRole r) => t('role_${r.value}');

  String type(TxnType x) => t(x == TxnType.income ? 'income' : 'expense');
}
