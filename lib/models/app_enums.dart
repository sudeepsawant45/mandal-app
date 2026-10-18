/// The four separate ledgers. Stored in `transactions.fund`.
enum Fund {
  householdDonation('household_donation'),
  commonMandal('common_mandal'),
  visarjan('visarjan'),
  tshirtSponsorship('tshirt_sponsorship');

  const Fund(this.value);
  final String value;

  static Fund fromValue(String v) {
    for (final f in Fund.values) {
      if (f.value == v) return f;
    }
    throw FormatException('Unknown fund "$v"');
  }
}

/// Direction of money for a ledger entry.
enum TxnType {
  income('income'),
  expense('expense');

  const TxnType(this.value);
  final String value;

  static TxnType fromValue(String v) {
    for (final t in TxnType.values) {
      if (t.value == v) return t;
    }
    throw FormatException('Unknown transaction type "$v"');
  }
}

enum PaymentMethod {
  cash('cash'),
  upi('upi'),
  bank('bank'),
  cheque('cheque'),
  other('other');

  const PaymentMethod(this.value);
  final String value;

  static PaymentMethod? tryParse(String? v) {
    if (v == null) return null;
    for (final m in PaymentMethod.values) {
      if (m.value == v) return m;
    }
    return null;
  }
}

/// `pending` = registered but not yet approved; has no access to data.
enum AppRole {
  admin('admin'),
  committee('committee'),
  viewer('viewer'),
  pending('pending');

  const AppRole(this.value);
  final String value;

  /// Unknown or missing values map to [pending] (no access) - fail closed.
  static AppRole fromValue(String? v) {
    for (final r in AppRole.values) {
      if (r.value == v) return r;
    }
    return AppRole.pending;
  }
}

enum ReportKind {
  household,
  commonFund,
  visarjanGroup,
  visarjanCombined,
  tshirt,
}
