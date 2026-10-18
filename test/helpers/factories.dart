import 'package:ganpati_mandal/domain/categories.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/mandal_settings.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';

/// Fixed "now" so duration-based rules are deterministic in tests.
final kNow = DateTime(2026, 9, 20, 12, 0);
final kCreated = DateTime(2026, 9, 18, 10, 0);

LedgerEntry makeEntry({
  String id = 'e1',
  Fund fund = Fund.commonMandal,
  TxnType type = TxnType.income,
  int paise = 100000,
  DateTime? date,
  String description = 'Test entry',
  String category = Categories.generalIncome,
  String createdBy = 'u1',
  String createdByName = 'Asha',
  DateTime? createdAt,
  String? householdId,
  String? householdName,
  String? visarjanGroupId,
  String? visarjanGroupName,
  String? sponsorId,
  String? sponsorName,
  String? contributorName,
  String? paymentMethod,
  String? notes,
  int? quantity,
  bool isDeleted = false,
}) {
  return LedgerEntry(
    id: id,
    fund: fund,
    type: type,
    amountPaise: paise,
    date: date ?? DateTime(2026, 9, 10),
    description: description,
    category: category,
    createdBy: createdBy,
    createdByName: createdByName,
    createdAt: createdAt ?? kCreated,
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
    isDeleted: isDeleted,
  );
}

LedgerEntry donation(
  String id,
  String householdId,
  int paise, {
  DateTime? date,
  bool deleted = false,
  String contributor = 'Contributor',
}) =>
    makeEntry(
      id: id,
      fund: Fund.householdDonation,
      type: TxnType.income,
      paise: paise,
      date: date,
      householdId: householdId,
      householdName: 'name-$householdId',
      contributorName: contributor,
      paymentMethod: 'cash',
      category: Categories.donation,
      description: 'Donation',
      isDeleted: deleted,
    );

LedgerEntry commonIncome(String id, int paise, {DateTime? date, bool deleted = false}) =>
    makeEntry(
      id: id,
      fund: Fund.commonMandal,
      type: TxnType.income,
      paise: paise,
      date: date,
      category: Categories.generalIncome,
      description: 'Common income',
      isDeleted: deleted,
    );

LedgerEntry commonExpense(
  String id,
  int paise, {
  String category = Categories.pujaMaterials,
  DateTime? date,
  bool deleted = false,
}) =>
    makeEntry(
      id: id,
      fund: Fund.commonMandal,
      type: TxnType.expense,
      paise: paise,
      date: date,
      category: category,
      description: 'Common expense',
      isDeleted: deleted,
    );

LedgerEntry visarjanIncome(
  String id,
  String groupId,
  int paise, {
  String contributor = 'Contributor',
  DateTime? date,
  bool deleted = false,
}) =>
    makeEntry(
      id: id,
      fund: Fund.visarjan,
      type: TxnType.income,
      paise: paise,
      date: date,
      visarjanGroupId: groupId,
      visarjanGroupName: 'snapshot-$groupId',
      contributorName: contributor,
      category: Categories.contribution,
      description: 'Contribution',
      isDeleted: deleted,
    );

LedgerEntry visarjanExpense(
  String id,
  String groupId,
  int paise, {
  DateTime? date,
  bool deleted = false,
}) =>
    makeEntry(
      id: id,
      fund: Fund.visarjan,
      type: TxnType.expense,
      paise: paise,
      date: date,
      visarjanGroupId: groupId,
      visarjanGroupName: 'snapshot-$groupId',
      category: Categories.visarjanExpense,
      description: 'Visarjan expense',
      isDeleted: deleted,
    );

LedgerEntry tshirtIncome(
  String id,
  String sponsorId,
  int paise, {
  DateTime? date,
  bool deleted = false,
}) =>
    makeEntry(
      id: id,
      fund: Fund.tshirtSponsorship,
      type: TxnType.income,
      paise: paise,
      date: date,
      sponsorId: sponsorId,
      sponsorName: 'snapshot-$sponsorId',
      category: Categories.sponsorship,
      description: 'Sponsorship',
      isDeleted: deleted,
    );

LedgerEntry tshirtExpense(
  String id,
  int paise, {
  int? quantity,
  DateTime? date,
  bool deleted = false,
}) =>
    makeEntry(
      id: id,
      fund: Fund.tshirtSponsorship,
      type: TxnType.expense,
      paise: paise,
      date: date,
      category: Categories.tshirtExpense,
      description: 'T-shirt printing',
      quantity: quantity,
      isDeleted: deleted,
    );

const kHouseholds = [
  Household(id: 'h1', name: 'Patil'),
  Household(id: 'h2', name: 'Deshmukh'),
  Household(id: 'h3', name: 'Joshi'),
];

const kGroups = [
  VisarjanGroup(id: 'g1', name: 'Kulkarni Family'),
  VisarjanGroup(id: 'g2', name: 'Sane Group'),
  VisarjanGroup(id: 'g3', name: 'Unused Group'),
];

const kSponsors = [
  Sponsor(id: 's1', name: 'ABC Traders'),
  Sponsor(id: 's2', name: 'XYZ Printers'),
];

const kSettings = MandalSettings(mandalName: 'Shree Ganesh Mandal', financialYear: '2026-27');
