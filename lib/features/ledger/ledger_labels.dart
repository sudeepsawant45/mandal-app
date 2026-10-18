import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

/// Wording of the income direction depends on the fund
/// (donation / income / contribution / sponsorship).
String entryTypeLabel(L10n l, Fund fund, TxnType type) {
  if (type == TxnType.expense) return l.t('expense');
  switch (fund) {
    case Fund.householdDonation:
      return l.t('donation');
    case Fund.commonMandal:
      return l.t('income');
    case Fund.visarjan:
      return l.t('contribution');
    case Fund.tshirtSponsorship:
      return l.t('sponsorship');
  }
}

String entryTitle(L10n l, LedgerEntry e) {
  String firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return '';
  }

  switch (e.fund) {
    case Fund.householdDonation:
      return firstNonEmpty([e.householdName, e.contributorName, e.description]);
    case Fund.commonMandal:
      return firstNonEmpty([e.description]);
    case Fund.visarjan:
      return e.isIncome
          ? firstNonEmpty([e.contributorName, e.description])
          : firstNonEmpty([e.description]);
    case Fund.tshirtSponsorship:
      return e.isIncome
          ? firstNonEmpty([e.sponsorName, e.description])
          : firstNonEmpty([e.description]);
  }
}

String entrySubtitle(L10n l, LedgerEntry e, {bool includeFund = false}) {
  final parts = <String>[formatDate(e.date)];
  if (includeFund) parts.add(l.fund(e.fund));
  switch (e.fund) {
    case Fund.householdDonation:
      if ((e.contributorName ?? '').isNotEmpty) parts.add(e.contributorName!);
      if (e.paymentMethod != null) parts.add(l.paymentMethod(e.paymentMethod));
    case Fund.commonMandal:
      parts.add(l.category(e.category));
    case Fund.visarjan:
      if ((e.visarjanGroupName ?? '').isNotEmpty) parts.add(e.visarjanGroupName!);
      if (e.isExpense) parts.add(l.t('expense'));
    case Fund.tshirtSponsorship:
      if (e.isExpense) {
        parts.add(l.t('expense'));
        if (e.quantity != null) parts.add('${l.t('quantity')}: ${e.quantity}');
      }
  }
  return parts.join(' • ');
}
