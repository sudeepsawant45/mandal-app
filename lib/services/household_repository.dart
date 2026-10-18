import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/utils/text_utils.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/master_data_repository.dart';

/// Households via /api/households. Admin-only writes (enforced by the server).
/// Households are archived (active=false), never deleted, so their historical
/// donations keep a valid reference.
class HouseholdRepository extends MasterDataRepository<Household> {
  HouseholdRepository(ApiClient api) : super(api, '/api/households', Household.fromMap);

  Stream<List<Household>> watchAll() =>
      watchList(sort: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<String> add({required String name, String? notes, required Actor actor}) {
    if (!Permissions.canManageHouseholds(actor.role)) {
      throw const AppException('err_permission');
    }
    return createItem({'name': name.trim(), 'notes': cleanOrNull(notes)});
  }

  Future<void> update(
    Household household, {
    required String name,
    String? notes,
    required bool active,
    required Actor actor,
  }) {
    if (!Permissions.canManageHouseholds(actor.role)) {
      throw const AppException('err_permission');
    }
    return updateItem(household.id, {
      'name': name.trim(),
      'notes': cleanOrNull(notes),
      'active': active,
    });
  }
}
