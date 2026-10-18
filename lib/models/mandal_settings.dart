import 'package:ganpati_mandal/core/utils/date_utils.dart';

/// Mandal settings (GET /api/settings) - name and financial year printed on every report.
class MandalSettings {
  const MandalSettings({
    required this.mandalName,
    required this.financialYear,
    this.configured = true,
  });

  final String mandalName;
  final String financialYear;

  /// False while showing the built-in fallback (nothing saved by an admin yet).
  final bool configured;

  /// Shown only until an admin saves real settings; never written automatically.
  factory MandalSettings.fallback(DateTime now) => MandalSettings(
        mandalName: 'Ganpati Mandal',
        financialYear: defaultFinancialYear(now),
        configured: false,
      );

  factory MandalSettings.fromMap(Map<String, dynamic> m, DateTime now) {
    final fallback = MandalSettings.fallback(now);
    final name = (m['mandalName'] as String?)?.trim();
    final year = (m['financialYear'] as String?)?.trim();
    return MandalSettings(
      mandalName: (name == null || name.isEmpty) ? fallback.mandalName : name,
      financialYear: (year == null || year.isEmpty) ? fallback.financialYear : year,
      configured: m['configured'] != false,
    );
  }
}
