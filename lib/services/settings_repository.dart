import 'dart:async';

import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/mandal_settings.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/polling.dart';

/// Mandal name and financial year via /api/settings (Admin writes).
class SettingsRepository {
  SettingsRepository(this._api);

  final ApiClient _api;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  Future<MandalSettings> fetch() async {
    final json = await _api.get('/api/settings');
    return MandalSettings.fromMap(json['settings'] as Map<String, dynamic>, DateTime.now());
  }

  Stream<MandalSettings> watch() => pollStream<MandalSettings>(
        load: fetch,
        every: const Duration(minutes: 5),
        refreshes: _changed.stream,
      );

  Future<void> save({
    required String mandalName,
    required String financialYear,
    required MandalSettings previous,
    required Actor actor,
  }) async {
    if (!Permissions.canConfigureSettings(actor.role)) {
      throw const AppException('err_permission');
    }
    final name = mandalName.trim();
    final year = financialYear.trim();
    if (name.isEmpty || name.length > AppConstants.maxNameLength) {
      throw const AppException('err_invalid_entry', 'mandalName');
    }
    if (year.isEmpty || year.length > 20) {
      throw const AppException('err_invalid_entry', 'financialYear');
    }
    try {
      await _api.put('/api/settings', body: {'mandalName': name, 'financialYear': year});
      _changed.add(null);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
