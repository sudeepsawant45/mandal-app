import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';
import 'package:ganpati_mandal/core/widgets/otp_code_field.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('InitialsAvatar.initialsOf', () {
    test('uses first and last word', () {
      expect(InitialsAvatar.initialsOf('Savita Patil'), 'SP');
      expect(InitialsAvatar.initialsOf('  amol  '), 'A');
    });
    test('handles empty and Devanagari names', () {
      expect(InitialsAvatar.initialsOf(''), '?');
      expect(InitialsAvatar.initialsOf('सविता पाटील'), 'सप');
    });
  });

  testWidgets('RoleBadge shows the translated role in both languages', (t) async {
    await t.pumpWidget(host(RoleBadge(role: AppRole.admin, l10n: L10n.en)));
    expect(find.text(L10n.en.t('role_admin')), findsOneWidget);
    await t.pumpWidget(host(RoleBadge(role: AppRole.admin, l10n: L10n.mr)));
    expect(find.text(L10n.mr.t('role_admin')), findsOneWidget);
  });

  testWidgets('OtpCodeField shows six boxes, mirrors typed digits and fires onCompleted once',
      (t) async {
    final c = TextEditingController();
    final completed = <String>[];
    await t.pumpWidget(host(Form(
      child: OtpCodeField(
        controller: c,
        autofocus: false,
        onCompleted: completed.add,
      ),
    )));

    await t.enterText(find.byType(TextFormField), '123');
    await t.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(completed, isEmpty);

    await t.enterText(find.byType(TextFormField), '123456');
    await t.pump();
    expect(completed, ['123456']);
  });

  testWidgets('OtpCodeField rejects non-digits and more than six characters', (t) async {
    final c = TextEditingController();
    await t.pumpWidget(host(OtpCodeField(controller: c, autofocus: false)));
    await t.enterText(find.byType(TextFormField), '12ab3456789');
    await t.pump();
    expect(c.text, '123456');
  });

  testWidgets('OtpCodeField validator is wired to the form', (t) async {
    final c = TextEditingController(text: '12');
    final key = GlobalKey<FormState>();
    await t.pumpWidget(host(Form(
      key: key,
      child: OtpCodeField(
        controller: c,
        autofocus: false,
        validator: (v) => (v ?? '').length == 6 ? null : 'bad',
      ),
    )));
    expect(key.currentState!.validate(), isFalse);
    c.text = '123456';
    expect(key.currentState!.validate(), isTrue);
  });

  test('theme builds and keeps income green, expense red', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(FundColors.income, isNot(FundColors.expense));
  });
}
