import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

/// One financial transaction (served by the API as /api/transactions).
///
/// Money is an integer number of paise. [fund] keeps the four ledgers apart:
/// household donations, common mandal fund, visarjan, T-shirt sponsorship.
/// Entries are never physically deleted - [isDeleted] marks a soft delete and
/// every calculation ignores soft-deleted entries.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.fund,
    required this.type,
    required this.amountPaise,
    required this.date,
    required this.description,
    required this.category,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.householdId,
    this.householdName,
    this.visarjanGroupId,
    this.visarjanGroupName,
    this.sponsorId,
    this.sponsorName,
    this.contributorName,
    this.paymentMethod,
    this.notes,
    this.quantity,
    this.isDeleted = false,
    this.updatedBy,
    this.updatedByName,
    this.updatedAt,
    this.deletedBy,
    this.deletedByName,
    this.deletedAt,
  });

  final String id;
  final Fund fund;
  final TxnType type;
  final int amountPaise;

  /// Calendar date of the transaction (time part is ignored).
  final DateTime date;
  final String description;
  final String category;

  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  final String? householdId;
  final String? householdName;
  final String? visarjanGroupId;
  final String? visarjanGroupName;
  final String? sponsorId;
  final String? sponsorName;
  final String? contributorName;
  final String? paymentMethod;
  final String? notes;

  /// Number of T-shirts (only for T-shirt expense entries).
  final int? quantity;

  final bool isDeleted;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;
  final String? deletedBy;
  final String? deletedByName;
  final DateTime? deletedAt;

  bool get isIncome => type == TxnType.income;
  bool get isExpense => type == TxnType.expense;

  /// The user-editable fields as the API expects them. The server owns
  /// everything else (author, timestamps, isDeleted, display-name snapshots)
  /// and REJECTS unknown keys, so none of those are sent. Optional fields are
  /// sent as explicit nulls so that edits can clear them.
  Map<String, dynamic> toApiBody({bool includeId = true}) => {
        if (includeId) 'id': id,
        'fund': fund.value,
        'type': type.value,
        'amountPaise': amountPaise,
        'date': apiDate(date),
        'description': description,
        'category': category,
        'householdId': householdId,
        'visarjanGroupId': visarjanGroupId,
        'sponsorId': sponsorId,
        'contributorName': contributorName,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'quantity': quantity,
      };

  /// Compact, primitive-only snapshot stored in the audit trail.
  Map<String, dynamic> auditSnapshot() => {
        'fund': fund.value,
        'type': type.value,
        'amountPaise': amountPaise,
        'date': formatDate(date),
        'description': description,
        'category': category,
        'householdId': householdId,
        'visarjanGroupId': visarjanGroupId,
        'sponsorId': sponsorId,
        'contributorName': contributorName,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'quantity': quantity,
        'isDeleted': isDeleted,
      };

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> m) {
    final date = readDate(m['date']);
    if (date == null) {
      throw FormatException('Transaction $id has no valid date');
    }
    return LedgerEntry(
      id: id,
      fund: Fund.fromValue(m['fund'] as String),
      type: TxnType.fromValue(m['type'] as String),
      amountPaise: (m['amountPaise'] as num).toInt(),
      date: dateOnly(date),
      description: (m['description'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      createdBy: (m['createdBy'] as String?) ?? '',
      createdByName: (m['createdByName'] as String?) ?? '',
      createdAt: readDate(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      householdId: m['householdId'] as String?,
      householdName: m['householdName'] as String?,
      visarjanGroupId: m['visarjanGroupId'] as String?,
      visarjanGroupName: m['visarjanGroupName'] as String?,
      sponsorId: m['sponsorId'] as String?,
      sponsorName: m['sponsorName'] as String?,
      contributorName: m['contributorName'] as String?,
      paymentMethod: m['paymentMethod'] as String?,
      notes: m['notes'] as String?,
      quantity: (m['quantity'] as num?)?.toInt(),
      isDeleted: (m['isDeleted'] as bool?) ?? false,
      updatedBy: m['updatedBy'] as String?,
      updatedByName: m['updatedByName'] as String?,
      updatedAt: readDate(m['updatedAt']),
      deletedBy: m['deletedBy'] as String?,
      deletedByName: m['deletedByName'] as String?,
      deletedAt: readDate(m['deletedAt']),
    );
  }

  LedgerEntry copyWith({
    String? id,
    bool? isDeleted,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
  }) =>
      LedgerEntry(
        id: id ?? this.id,
        fund: fund,
        type: type,
        amountPaise: amountPaise,
        date: date,
        description: description,
        category: category,
        createdBy: createdBy ?? this.createdBy,
        createdByName: createdByName ?? this.createdByName,
        createdAt: createdAt ?? this.createdAt,
        householdId: householdId,
        householdName: householdName,
        visarjanGroupId: visarjanGroupId,
        visarjanGroupName: visarjanGroupName,
        sponsorId: sponsorId,
        sponsorName: sponsorName,
        contributorName: contributorName,
        paymentMethod: paymentMethod,
        notes: notes,
        quantity: quantity,
        isDeleted: isDeleted ?? this.isDeleted,
        updatedBy: updatedBy,
        updatedByName: updatedByName,
        updatedAt: updatedAt,
        deletedBy: deletedBy,
        deletedByName: deletedByName,
        deletedAt: deletedAt,
      );
}
