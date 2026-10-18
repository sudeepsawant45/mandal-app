import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/l10n/l10n_en.dart';
import 'package:ganpati_mandal/core/l10n/l10n_mr.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

void main() {
  test('English and Marathi define exactly the same keys', () {
    expect(kMr.keys.toSet().difference(kEn.keys.toSet()), isEmpty, reason: 'only in mr');
    expect(kEn.keys.toSet().difference(kMr.keys.toSet()), isEmpty, reason: 'only in en');
  });

  test('no empty translations', () {
    expect(kEn.entries.where((e) => e.value.trim().isEmpty), isEmpty);
    expect(kMr.entries.where((e) => e.value.trim().isEmpty), isEmpty);
  });

  test('unknown key falls back to the key itself', () {
    expect(L10n.en.t('no_such_key'), 'no_such_key');
    expect(L10n.mr.t('no_such_key'), 'no_such_key');
  });

  test('every enum value has a label in both languages', () {
    for (final l in [L10n.en, L10n.mr]) {
      for (final f in Fund.values) {
        expect(l.fund(f), isNot('fund_${f.value}'));
      }
      for (final r in AppRole.values) {
        expect(l.role(r), isNot('role_${r.value}'));
      }
      for (final m in PaymentMethod.values) {
        expect(l.paymentMethod(m.value), isNot('pm_${m.value}'));
      }
    }
  });

  test('toggled switches language', () {
    expect(L10n.en.toggled.lang, 'mr');
    expect(L10n.mr.toggled.lang, 'en');
  });
}
