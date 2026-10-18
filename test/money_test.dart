import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/utils/money.dart';

void main() {
  group('Money.format (Indian grouping)', () {
    test('small amounts', () {
      expect(Money.format(0), '₹0');
      expect(Money.format(100), '₹1');
      expect(Money.format(99900), '₹999');
    });

    test('lakh / crore grouping', () {
      expect(Money.format(100000), '₹1,000');
      expect(Money.format(10000000), '₹1,00,000');
      expect(Money.format(123456789), '₹12,34,567.89');
      expect(Money.format(1000000000), '₹1,00,00,000');
    });

    test('paise shown only when non-zero', () {
      expect(Money.format(150050), '₹1,500.50');
      expect(Money.format(150005), '₹1,500.05');
      expect(Money.format(150000), '₹1,500');
    });

    test('negative amounts and custom symbol', () {
      expect(Money.format(-20000), '-₹200');
      expect(Money.format(375050, symbol: 'Rs. '), 'Rs. 3,750.50');
    });
  });

  group('Money.parseToPaise (exact, no floating point)', () {
    test('plain and decimal values', () {
      expect(Money.parseToPaise('1500'), 150000);
      expect(Money.parseToPaise('1500.5'), 150050);
      expect(Money.parseToPaise('1500.50'), 150050);
      expect(Money.parseToPaise('0.05'), 5);
      expect(Money.parseToPaise('0'), 0);
    });

    test('separators, symbol and whitespace are tolerated', () {
      expect(Money.parseToPaise('1,50,000'), 15000000);
      expect(Money.parseToPaise(' ₹ 2,500.75 '), 250075);
    });

    test('Devanagari digits are understood', () {
      expect(Money.parseToPaise('१५००'), 150000);
      expect(Money.parseToPaise('२५०.५०'), 25050);
    });

    test('invalid input returns null', () {
      expect(Money.parseToPaise(null), isNull);
      expect(Money.parseToPaise(''), isNull);
      expect(Money.parseToPaise('abc'), isNull);
      expect(Money.parseToPaise('-5'), isNull);
      expect(Money.parseToPaise('1.234'), isNull); // more than 2 decimals
      expect(Money.parseToPaise('1e5'), isNull);
      expect(Money.parseToPaise('12.'), isNull);
      expect(Money.parseToPaise('.5'), isNull);
    });

    test('values that break binary floating point are exact in paise', () {
      // 0.1 + 0.2 != 0.3 with doubles; with integer paise it is exact.
      final sum = Money.parseToPaise('0.10')! + Money.parseToPaise('0.20')!;
      expect(sum, Money.parseToPaise('0.30'));
      expect(Money.parseToPaise('19.99')! * 3, 5997);
    });
  });

  test('toInputText round-trips with parseToPaise', () {
    for (final paise in [0, 5, 100, 150050, 123456789]) {
      expect(Money.parseToPaise(Money.toInputText(paise)), paise);
    }
  });
}
