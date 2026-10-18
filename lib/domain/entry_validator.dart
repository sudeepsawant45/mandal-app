import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';

class ValidationIssue {
  const ValidationIssue(this.field, this.messageKey);

  /// Logical field name: amount, description, category, household, group,
  /// sponsor, contributor, paymentMethod, quantity, notes, type, fund, id.
  final String field;

  /// L10n key (v_*).
  final String messageKey;

  @override
  String toString() => '$field: $messageKey';
}

/// Client-side mirror of the backend's entry validation (backend/src/validation.js).
/// The server is the real enforcement; this gives users immediate, translated feedback.
class EntryValidator {
  EntryValidator._();

  static bool _blank(String? s) => s == null || s.trim().isEmpty;

  static List<ValidationIssue> validate(LedgerEntry e) {
    final issues = <ValidationIssue>[];
    void add(String field, String key) => issues.add(ValidationIssue(field, key));

    if (_blank(e.id)) add('id', 'v_required');

    if (e.amountPaise <= 0) {
      add('amount', 'v_amount_positive');
    } else if (e.amountPaise > AppConstants.maxAmountPaise) {
      add('amount', 'v_amount_too_large');
    }

    if (_blank(e.description)) {
      add('description', 'v_required');
    } else if (e.description.length > AppConstants.maxDescriptionLength) {
      add('description', 'v_too_long');
    }

    if (_blank(e.category)) {
      add('category', 'v_required');
    } else if (e.category.length > AppConstants.maxCategoryLength) {
      add('category', 'v_too_long');
    }

    if (e.notes != null && e.notes!.length > AppConstants.maxNotesLength) {
      add('notes', 'v_too_long');
    }

    if (e.paymentMethod != null && PaymentMethod.tryParse(e.paymentMethod) == null) {
      add('paymentMethod', 'v_invalid');
    }

    switch (e.fund) {
      case Fund.householdDonation:
        if (e.type != TxnType.income) add('type', 'v_type_not_allowed');
        if (_blank(e.householdId)) add('household', 'v_required');
        if (_blank(e.contributorName)) add('contributor', 'v_required');
        if (_blank(e.paymentMethod)) add('paymentMethod', 'v_required');
        if (e.visarjanGroupId != null || e.sponsorId != null) {
          add('fund', 'v_cross_fund_reference');
        }
      case Fund.commonMandal:
        if (e.householdId != null || e.visarjanGroupId != null || e.sponsorId != null) {
          add('fund', 'v_cross_fund_reference');
        }
      case Fund.visarjan:
        if (_blank(e.visarjanGroupId)) add('group', 'v_required');
        if (e.type == TxnType.income && _blank(e.contributorName)) {
          add('contributor', 'v_required');
        }
        if (e.householdId != null || e.sponsorId != null) {
          add('fund', 'v_cross_fund_reference');
        }
      case Fund.tshirtSponsorship:
        if (e.type == TxnType.income && _blank(e.sponsorId)) {
          add('sponsor', 'v_required');
        }
        if (e.type == TxnType.expense && e.sponsorId != null) {
          add('sponsor', 'v_invalid');
        }
        if (e.householdId != null || e.visarjanGroupId != null) {
          add('fund', 'v_cross_fund_reference');
        }
    }

    final qty = e.quantity;
    if (qty != null) {
      if (e.fund != Fund.tshirtSponsorship || e.type != TxnType.expense) {
        add('quantity', 'v_quantity_not_allowed');
      } else if (qty <= 0 || qty > AppConstants.maxQuantity) {
        add('quantity', 'v_quantity_positive');
      }
    }

    return issues;
  }

  /// True when [candidate] looks like an accidental double submission: an
  /// existing, live entry of the same fund/type/amount/date/references and
  /// text that was created within [window] of [now]. A UI may ask the user to
  /// confirm; it is a warning, not a hard block (two identical donations can
  /// be genuine). Double taps and retries of the *same* form are prevented
  /// separately because the entry id is generated once per form.
  static bool isLikelyDuplicate(
    LedgerEntry candidate,
    Iterable<LedgerEntry> existing, {
    required DateTime now,
    Duration window = AppConstants.duplicateWindow,
  }) {
    String norm(String? s) => (s ?? '').trim().toLowerCase();
    for (final e in existing) {
      if (e.id == candidate.id || e.isDeleted) continue;
      if (now.difference(e.createdAt).abs() > window) continue;
      if (e.fund == candidate.fund &&
          e.type == candidate.type &&
          e.amountPaise == candidate.amountPaise &&
          sameDay(e.date, candidate.date) &&
          e.householdId == candidate.householdId &&
          e.visarjanGroupId == candidate.visarjanGroupId &&
          e.sponsorId == candidate.sponsorId &&
          norm(e.contributorName) == norm(candidate.contributorName) &&
          norm(e.description) == norm(candidate.description)) {
        return true;
      }
    }
    return false;
  }

  /// Case- and whitespace-insensitive name clash check for households,
  /// visarjan groups and sponsors. [exceptName] is the record's own current name (when editing) and is ignored.
  static bool isDuplicateName(
    Iterable<String> existingNames,
    String candidate, {
    String? exceptName,
  }) {
    String norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final c = norm(candidate);
    final skip = exceptName == null ? null : norm(exceptName);
    for (final n in existingNames) {
      final x = norm(n);
      if (skip != null && x == skip) continue;
      if (x == c) return true;
    }
    return false;
  }
}
