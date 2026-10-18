import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/widgets/form_fields.dart';
import 'package:ganpati_mandal/core/widgets/fund_summary_card.dart';
import 'package:ganpati_mandal/core/widgets/read_only_banner.dart';
import 'package:ganpati_mandal/features/ledger/entry_tile.dart';

import '../helpers/factories.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('AmountFormField.validate', () {
    final l = L10n.en;
    test('accepts valid amounts', () {
      expect(AmountFormField.validate(l, '500'), isNull);
      expect(AmountFormField.validate(l, '1,500.50'), isNull);
    });
    test('rejects empty, text, zero and over-limit values', () {
      expect(AmountFormField.validate(l, ''), l.t('v_amount_invalid'));
      expect(AmountFormField.validate(l, 'abc'), l.t('v_amount_invalid'));
      expect(AmountFormField.validate(l, '0'), l.t('v_amount_positive'));
      expect(AmountFormField.validate(l, '99999999999'), l.t('v_amount_too_large'));
    });
  });

  testWidgets('AmountFormField shows an error for zero and none for a valid amount', (t) async {
    final c = TextEditingController(text: '0');
    final key = GlobalKey<FormState>();
    await t.pumpWidget(host(Form(key: key, child: AmountFormField(controller: c, l10n: L10n.en))));
    expect(key.currentState!.validate(), isFalse);
    await t.pump();
    expect(find.text(L10n.en.t('v_amount_positive')), findsOneWidget);

    c.text = '250';
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('ReadOnlyBanner shows the read-only message in both languages', (t) async {
    await t.pumpWidget(host(ReadOnlyBanner(l10n: L10n.en)));
    expect(find.text(L10n.en.t('viewer_read_only')), findsOneWidget);
    await t.pumpWidget(host(ReadOnlyBanner(l10n: L10n.mr)));
    expect(find.text(L10n.mr.t('viewer_read_only')), findsOneWidget);
  });

  testWidgets('FundSummaryCard shows its own lines and fires callbacks', (t) async {
    var opened = false;
    await t.pumpWidget(host(FundSummaryCard(
      title: 'Common fund',
      icon: Icons.account_balance,
      color: Colors.blue,
      lines: const [
        SummaryLine('Income', 500000),
        SummaryLine('Balance', -20000, emphasize: true, signColored: true),
      ],
      openLabel: 'Open',
      onOpen: () => opened = true,
    )));
    expect(find.text('Common fund'), findsOneWidget);
    expect(find.text('₹5,000'), findsOneWidget);
    expect(find.text('-₹200'), findsOneWidget);
    await t.tap(find.text('Open'));
    expect(opened, isTrue);
  });

  testWidgets('EntryTile shows sign and amount; deleted entries are marked', (t) async {
    await t.pumpWidget(host(Column(children: [
      EntryTile(entry: commonIncome('a', 150050), l10n: L10n.en),
      EntryTile(entry: commonExpense('b', 20000, deleted: true), l10n: L10n.en),
    ])));
    expect(find.text('+₹1,500.50'), findsOneWidget);
    expect(find.text('-₹200'), findsOneWidget);
    expect(find.textContaining(L10n.en.t('deleted')), findsOneWidget);
  });
}
