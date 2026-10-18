import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/domain/categories.dart';
import 'package:ganpati_mandal/domain/entry_validator.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

import 'helpers/factories.dart';

bool hasIssue(List<ValidationIssue> issues, String field, [String? key]) =>
    issues.any((i) => i.field == field && (key == null || i.messageKey == key));

void main() {
  group('valid entries', () {
    test('each fund has a valid example', () {
      expect(EntryValidator.validate(donation('d', 'h1', 100000)), isEmpty);
      expect(EntryValidator.validate(commonIncome('c', 100000)), isEmpty);
      expect(EntryValidator.validate(commonExpense('c', 100000)), isEmpty);
      expect(EntryValidator.validate(visarjanIncome('v', 'g1', 100000)), isEmpty);
      expect(EntryValidator.validate(visarjanExpense('v', 'g1', 100000)), isEmpty);
      expect(EntryValidator.validate(tshirtIncome('t', 's1', 100000)), isEmpty);
      expect(EntryValidator.validate(tshirtExpense('t', 100000, quantity: 50)), isEmpty);
    });
  });

  group('amounts', () {
    test('zero and negative are rejected', () {
      expect(hasIssue(EntryValidator.validate(commonIncome('a', 0)), 'amount', 'v_amount_positive'), isTrue);
      expect(hasIssue(EntryValidator.validate(commonIncome('a', -500)), 'amount', 'v_amount_positive'), isTrue);
    });

    test('absurdly large amounts are rejected', () {
      final issues = EntryValidator.validate(commonIncome('a', AppConstants.maxAmountPaise + 1));
      expect(hasIssue(issues, 'amount', 'v_amount_too_large'), isTrue);
      expect(EntryValidator.validate(commonIncome('a', AppConstants.maxAmountPaise)), isEmpty);
    });
  });

  group('required fields', () {
    test('description and category are required', () {
      final e = makeEntry(description: '   ', category: '');
      final issues = EntryValidator.validate(e);
      expect(hasIssue(issues, 'description', 'v_required'), isTrue);
      expect(hasIssue(issues, 'category', 'v_required'), isTrue);
    });

    test('over-long text is rejected', () {
      final e = makeEntry(
        description: 'x' * (AppConstants.maxDescriptionLength + 1),
        notes: 'y' * (AppConstants.maxNotesLength + 1),
      );
      final issues = EntryValidator.validate(e);
      expect(hasIssue(issues, 'description', 'v_too_long'), isTrue);
      expect(hasIssue(issues, 'notes', 'v_too_long'), isTrue);
    });

    test('household donation needs household, contributor and payment method', () {
      final e = makeEntry(
        fund: Fund.householdDonation,
        category: Categories.donation,
        description: 'Donation',
      );
      final issues = EntryValidator.validate(e);
      expect(hasIssue(issues, 'household'), isTrue);
      expect(hasIssue(issues, 'contributor'), isTrue);
      expect(hasIssue(issues, 'paymentMethod'), isTrue);
    });

    test('household donations cannot be expenses', () {
      final e = makeEntry(
        fund: Fund.householdDonation,
        type: TxnType.expense,
        householdId: 'h1',
        contributorName: 'X',
        paymentMethod: 'cash',
        category: Categories.donation,
      );
      expect(hasIssue(EntryValidator.validate(e), 'type', 'v_type_not_allowed'), isTrue);
    });

    test('unknown payment method is rejected', () {
      final e = makeEntry(
        fund: Fund.householdDonation,
        householdId: 'h1',
        contributorName: 'X',
        paymentMethod: 'bitcoin',
        category: Categories.donation,
      );
      expect(hasIssue(EntryValidator.validate(e), 'paymentMethod', 'v_invalid'), isTrue);
    });

    test('visarjan entries need a group; contributions need a contributor', () {
      final noGroup = makeEntry(fund: Fund.visarjan, category: Categories.contribution);
      expect(hasIssue(EntryValidator.validate(noGroup), 'group'), isTrue);
      expect(hasIssue(EntryValidator.validate(noGroup), 'contributor'), isTrue);

      final expenseNoContributor = makeEntry(
        fund: Fund.visarjan,
        type: TxnType.expense,
        visarjanGroupId: 'g1',
        category: Categories.visarjanExpense,
      );
      expect(EntryValidator.validate(expenseNoContributor), isEmpty);
    });

    test('T-shirt sponsorship needs a sponsor; expenses must not have one', () {
      final noSponsor = makeEntry(fund: Fund.tshirtSponsorship, category: Categories.sponsorship);
      expect(hasIssue(EntryValidator.validate(noSponsor), 'sponsor', 'v_required'), isTrue);

      final expenseWithSponsor = makeEntry(
        fund: Fund.tshirtSponsorship,
        type: TxnType.expense,
        sponsorId: 's1',
        category: Categories.tshirtExpense,
      );
      expect(hasIssue(EntryValidator.validate(expenseWithSponsor), 'sponsor', 'v_invalid'), isTrue);
    });
  });

  group('cross-fund references are rejected', () {
    test('common fund entry carrying a household / group / sponsor', () {
      for (final e in [
        makeEntry(householdId: 'h1'),
        makeEntry(visarjanGroupId: 'g1'),
        makeEntry(sponsorId: 's1'),
      ]) {
        expect(hasIssue(EntryValidator.validate(e), 'fund', 'v_cross_fund_reference'), isTrue);
      }
    });

    test('visarjan entry carrying a household or sponsor', () {
      final e = makeEntry(
        fund: Fund.visarjan,
        visarjanGroupId: 'g1',
        contributorName: 'A',
        householdId: 'h1',
        category: Categories.contribution,
      );
      expect(hasIssue(EntryValidator.validate(e), 'fund', 'v_cross_fund_reference'), isTrue);
    });

    test('household donation carrying a visarjan group', () {
      final e = makeEntry(
        fund: Fund.householdDonation,
        householdId: 'h1',
        contributorName: 'A',
        paymentMethod: 'upi',
        visarjanGroupId: 'g1',
        category: Categories.donation,
      );
      expect(hasIssue(EntryValidator.validate(e), 'fund', 'v_cross_fund_reference'), isTrue);
    });

    test('T-shirt entry carrying a household', () {
      final e = makeEntry(
        fund: Fund.tshirtSponsorship,
        sponsorId: 's1',
        householdId: 'h1',
        category: Categories.sponsorship,
      );
      expect(hasIssue(EntryValidator.validate(e), 'fund', 'v_cross_fund_reference'), isTrue);
    });
  });

  group('quantity', () {
    test('only allowed on T-shirt expenses', () {
      expect(
        hasIssue(EntryValidator.validate(makeEntry(quantity: 5)), 'quantity', 'v_quantity_not_allowed'),
        isTrue,
      );
      expect(
        hasIssue(
          EntryValidator.validate(tshirtIncome('t', 's1', 100).copyWith()),
          'quantity',
        ),
        isFalse,
      );
    });

    test('must be positive', () {
      final e = makeEntry(
        fund: Fund.tshirtSponsorship,
        type: TxnType.expense,
        category: Categories.tshirtExpense,
        quantity: 0,
      );
      expect(hasIssue(EntryValidator.validate(e), 'quantity', 'v_quantity_positive'), isTrue);
    });
  });

  group('duplicate submissions', () {
    final original = donation('d1', 'h1', 100000, date: DateTime(2026, 9, 10)).copyWith(
      createdAt: DateTime(2026, 9, 20, 11, 58),
    );

    test('identical entry created moments ago is flagged', () {
      final again = donation('d2', 'h1', 100000, date: DateTime(2026, 9, 10));
      expect(EntryValidator.isLikelyDuplicate(again, [original], now: kNow), isTrue);
    });

    test('the same id is never a duplicate of itself (idempotent retry)', () {
      expect(EntryValidator.isLikelyDuplicate(original, [original], now: kNow), isFalse);
    });

    test('different amount, household, date or contributor is not a duplicate', () {
      expect(
        EntryValidator.isLikelyDuplicate(donation('x', 'h1', 100001), [original], now: kNow),
        isFalse,
      );
      expect(
        EntryValidator.isLikelyDuplicate(donation('x', 'h2', 100000), [original], now: kNow),
        isFalse,
      );
      expect(
        EntryValidator.isLikelyDuplicate(
          donation('x', 'h1', 100000, date: DateTime(2026, 9, 11)),
          [original],
          now: kNow,
        ),
        isFalse,
      );
      expect(
        EntryValidator.isLikelyDuplicate(
          donation('x', 'h1', 100000, date: DateTime(2026, 9, 10), contributor: 'Someone else'),
          [original],
          now: kNow,
        ),
        isFalse,
      );
    });

    test('an old identical entry is outside the window', () {
      final old = original.copyWith(createdAt: DateTime(2026, 9, 1));
      final again = donation('d2', 'h1', 100000, date: DateTime(2026, 9, 10));
      expect(EntryValidator.isLikelyDuplicate(again, [old], now: kNow), isFalse);
    });

    test('a soft-deleted identical entry does not count', () {
      final deleted = original.copyWith(isDeleted: true);
      final again = donation('d2', 'h1', 100000, date: DateTime(2026, 9, 10));
      expect(EntryValidator.isLikelyDuplicate(again, [deleted], now: kNow), isFalse);
    });

    test('entries of different funds are never duplicates', () {
      final common = commonIncome('c1', 100000, date: DateTime(2026, 9, 10))
          .copyWith(createdAt: DateTime(2026, 9, 20, 11, 59));
      final visarjan = visarjanIncome('v1', 'g1', 100000, date: DateTime(2026, 9, 10));
      expect(EntryValidator.isLikelyDuplicate(visarjan, [common], now: kNow), isFalse);
    });
  });

  group('duplicate names', () {
    test('case and spacing are ignored', () {
      expect(EntryValidator.isDuplicateName(['Patil Family'], '  patil   family '), isTrue);
      expect(EntryValidator.isDuplicateName(['Patil'], 'Joshi'), isFalse);
    });

    test('editing a record may keep its own name', () {
      expect(
        EntryValidator.isDuplicateName(['Patil', 'Joshi'], 'Patil', exceptName: 'Patil'),
        isFalse,
      );
      expect(
        EntryValidator.isDuplicateName(['Patil', 'Joshi'], 'Joshi', exceptName: 'Patil'),
        isTrue,
      );
    });
  });
}
