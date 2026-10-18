import 'package:ganpati_mandal/models/app_enums.dart';

/// Category keys stored in `transactions.category`. Display names come from
/// L10n (`cat_<key>`), so stored data stays language neutral.
class Categories {
  Categories._();

  static const donation = 'donation';
  static const contribution = 'contribution';
  static const visarjanExpense = 'visarjan_expense';
  static const sponsorship = 'sponsorship';
  static const tshirtExpense = 'tshirt_expense';
  static const generalIncome = 'general_income';
  static const bhajanInstruments = 'bhajan_instruments';
  static const pujaMaterials = 'puja_materials';
  static const otherExpense = 'other_expense';

  static const commonIncome = [generalIncome];
  static const commonExpense = [bhajanInstruments, pujaMaterials, otherExpense];

  /// Categories the user may choose from for a fund/type combination.
  static List<String> optionsFor(Fund fund, TxnType type) {
    switch (fund) {
      case Fund.householdDonation:
        return const [donation];
      case Fund.commonMandal:
        return type == TxnType.income ? commonIncome : commonExpense;
      case Fund.visarjan:
        return type == TxnType.income ? const [contribution] : const [visarjanExpense];
      case Fund.tshirtSponsorship:
        return type == TxnType.income ? const [sponsorship] : const [tshirtExpense];
    }
  }

  static String defaultFor(Fund fund, TxnType type) => optionsFor(fund, type).first;

  /// Description used when an income entry is saved without free text. The
  /// brief does not ask for a description on donations / contributions /
  /// sponsorships, but every ledger entry needs one.
  static String? defaultDescription(Fund fund, TxnType type) {
    if (type == TxnType.expense) return null;
    switch (fund) {
      case Fund.householdDonation:
        return 'Donation';
      case Fund.visarjan:
        return 'Contribution';
      case Fund.tshirtSponsorship:
        return 'Sponsorship';
      case Fund.commonMandal:
        return null;
    }
  }

  /// Allowed directions per fund.
  static List<TxnType> allowedTypes(Fund fund) {
    switch (fund) {
      case Fund.householdDonation:
        return const [TxnType.income];
      case Fund.commonMandal:
      case Fund.visarjan:
      case Fund.tshirtSponsorship:
        return const [TxnType.income, TxnType.expense];
    }
  }
}
