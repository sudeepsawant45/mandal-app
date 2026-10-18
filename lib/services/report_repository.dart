import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/mandal_settings.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';
import 'package:ganpati_mandal/services/api_client.dart';

/// What the server returns for one report: only the entries of ONE fund (and,
/// for the individual visarjan report, ONE group), already period-filtered with
/// deleted entries removed, plus the master data and settings printed on it.
class ReportPayload {
  const ReportPayload({
    required this.entries,
    required this.households,
    required this.groups,
    required this.sponsors,
    required this.settings,
    required this.totals,
  });

  final List<LedgerEntry> entries;
  final List<Household> households;
  final List<VisarjanGroup> groups;
  final List<Sponsor> sponsors;
  final MandalSettings settings;

  /// Authoritative server-side totals (integer paise), as sent.
  final Map<String, dynamic> totals;
}

/// GET /api/reports/data - the data behind the PDF / share-sheet export.
/// PDF layout, language and sharing stay on the device.
class ReportRepository {
  ReportRepository(this._api);

  final ApiClient _api;

  static String kindValue(ReportKind k) {
    switch (k) {
      case ReportKind.household:
        return 'household';
      case ReportKind.commonFund:
        return 'common_fund';
      case ReportKind.visarjanGroup:
        return 'visarjan_group';
      case ReportKind.visarjanCombined:
        return 'visarjan_combined';
      case ReportKind.tshirt:
        return 'tshirt';
    }
  }

  Future<ReportPayload> fetch(
    ReportKind kind, {
    String? groupId,
    DateTime? from,
    DateTime? to,
  }) async {
    final json = await _api.get('/api/reports/data', query: {
      'kind': kindValue(kind),
      if (groupId != null) 'groupId': groupId,
      if (from != null) 'from': apiDate(from),
      if (to != null) 'to': apiDate(to),
    });
    List<T> list<T>(String key, T Function(String, Map<String, dynamic>) f) => [
          for (final raw in (json[key] as List?) ?? const [])
            f((raw as Map<String, dynamic>)['id'] as String, raw),
        ];
    return ReportPayload(
      entries: list('entries', LedgerEntry.fromMap),
      households: list('households', Household.fromMap),
      groups: list('groups', VisarjanGroup.fromMap),
      sponsors: list('sponsors', Sponsor.fromMap),
      settings: MandalSettings.fromMap(json['settings'] as Map<String, dynamic>, DateTime.now()),
      totals: (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
