DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String pad2(int n) => n.toString().padLeft(2, '0');

/// dd/MM/yyyy - the common Indian format. Implemented by hand so it needs no
/// locale data initialisation.
String formatDate(DateTime d) => '${pad2(d.day)}/${pad2(d.month)}/${d.year}';

String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${pad2(d.hour)}:${pad2(d.minute)}';

/// File-name friendly timestamp: 20261016_1130
String fileStamp(DateTime d) =>
    '${d.year}${pad2(d.month)}${pad2(d.day)}_${pad2(d.hour)}${pad2(d.minute)}';

/// Reads a date from an API value: epoch milliseconds (int), an ISO-8601 string,
/// a 'YYYY-MM-DD' calendar date (parsed as a LOCAL date, never shifted by a
/// time zone) or a [DateTime].
DateTime? readDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (m != null) {
      return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    }
    return DateTime.tryParse(value);
  }
  return null;
}

/// 'YYYY-MM-DD' for the API (calendar date, no time zone).
String apiDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${pad2(d.month)}-${pad2(d.day)}';

/// Indian financial year (April-March), e.g. 2026-10-16 -> "2026-27".
/// Only used as a fallback until an admin configures the year in Settings.
String defaultFinancialYear(DateTime now) {
  final startYear = now.month >= 4 ? now.year : now.year - 1;
  final endShort = (startYear + 1) % 100;
  return '$startYear-${pad2(endShort)}';
}

/// "01/09/2026 - 30/09/2026", "from 01/09/2026", "until 30/09/2026" or [allLabel].
String periodText(
  DateTime? from,
  DateTime? to, {
  required String allLabel,
  required String fromWord,
  required String untilWord,
}) {
  if (from == null && to == null) return allLabel;
  if (from != null && to != null) return '${formatDate(from)} - ${formatDate(to)}';
  if (from != null) return '$fromWord ${formatDate(from)}';
  return '$untilWord ${formatDate(to!)}';
}
