import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/utils/text_utils.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/master_data_repository.dart';

/// T-shirt sponsors via /api/sponsors. Archived, never deleted.
class SponsorRepository extends MasterDataRepository<Sponsor> {
  SponsorRepository(ApiClient api) : super(api, '/api/sponsors', Sponsor.fromMap);

  Stream<List<Sponsor>> watchAll() =>
      watchList(sort: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<String> add({
    required String name,
    String? contact,
    String? notes,
    required Actor actor,
  }) {
    if (!Permissions.canManageGroupsAndSponsors(actor.role)) {
      throw const AppException('err_permission');
    }
    return createItem({
      'name': name.trim(),
      'contact': cleanOrNull(contact),
      'notes': cleanOrNull(notes),
    });
  }

  Future<void> update(
    Sponsor sponsor, {
    required String name,
    String? contact,
    String? notes,
    required bool active,
    required Actor actor,
  }) {
    if (!Permissions.canManageGroupsAndSponsors(actor.role)) {
      throw const AppException('err_permission');
    }
    return updateItem(sponsor.id, {
      'name': name.trim(),
      'contact': cleanOrNull(contact),
      'notes': cleanOrNull(notes),
      'active': active,
    });
  }
}
