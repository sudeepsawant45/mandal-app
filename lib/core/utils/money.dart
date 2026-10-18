/// Exact-money helpers. All amounts in the app are integer paise (1 Rs = 100
/// paise); doubles are never used for money.
class Money {
  Money._();

  static const rupeeSymbol = '₹'; // ₹

  /// Formats paise with Indian digit grouping, e.g. 123456789 -> "₹12,34,567.89".
  /// Whole-rupee amounts omit the ".00".
  static String format(int paise, {String symbol = rupeeSymbol}) {
    final negative = paise < 0;
    final abs = paise.abs();
    final rupees = abs ~/ 100;
    final rem = abs % 100;
    final grouped = _groupIndian(rupees.toString());
    final body = rem == 0 ? grouped : '$grouped.${rem.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}$symbol$body';
  }

  static String _groupIndian(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  /// Parses user input such as "1,500", "₹ 1500.50" or Devanagari digits
  /// ("१५००") into paise using string arithmetic only (no floating point).
  /// Returns null for anything that is not a plain non-negative decimal with
  /// at most two decimal places. A result of 0 is returned for "0"; callers
  /// that need a positive amount must check `> 0`.
  static int? parseToPaise(String? input) {
    if (input == null) return null;
    var s = _devanagariToAscii(input.trim());
    s = s.replaceAll(',', '').replaceAll(rupeeSymbol, '').replaceAll(RegExp(r'\s'), '');
    final match = RegExp(r'^(\d{1,12})(?:\.(\d{1,2}))?$').firstMatch(s);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final frac = (match.group(2) ?? '').padRight(2, '0');
    final fracValue = frac.isEmpty ? 0 : int.parse(frac);
    return whole * 100 + fracValue;
  }

  static String _devanagariToAscii(String s) {
    final b = StringBuffer();
    for (final unit in s.runes) {
      if (unit >= 0x0966 && unit <= 0x096F) {
        b.writeCharCode(0x30 + (unit - 0x0966));
      } else {
        b.writeCharCode(unit);
      }
    }
    return b.toString();
  }

  /// Plain decimal text for an edit field, e.g. 150050 -> "1500.50".
  static String toInputText(int paise) {
    final rupees = paise ~/ 100;
    final rem = paise % 100;
    return rem == 0 ? '$rupees' : '$rupees.${rem.toString().padLeft(2, '0')}';
  }
}
