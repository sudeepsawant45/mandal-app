import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/core/utils/text_utils.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/master_data_repository.dart';

/// Visarjan groups via /api/visarjan-groups. Each group is its own account;
/// groups are archived, never deleted.
class VisarjanRepository extends MasterDataRepository<VisarjanGroup> {
  VisarjanRepository(ApiClient api) : super(api, '/api/visarjan-groups', VisarjanGroup.fromMap);

  Stream<List<VisarjanGroup>> watchAll() =>
      watchList(sort: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<String> add({required String name, String? notes, required Actor actor}) {
    if (!Permissions.canManageGroupsAndSponsors(actor.role)) {
      throw const AppException('err_permission');
    }
    return createItem({'name': name.trim(), 'notes': cleanOrNull(notes)});
  }

  Future<void> update(
    VisarjanGroup group, {
    required String name,
    String? notes,
    required bool active,
    required Actor actor,
  }) {
    if (!Permissions.canManageGroupsAndSponsors(actor.role)) {
      throw const AppException('err_permission');
    }
    return updateItem(group.id, {
      'name': name.trim(),
      'notes': cleanOrNull(notes),
      'active': active,
    });
  }
}
