import 'dart:async';

import 'package:ganpati_mandal/core/errors/app_exception.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/polling.dart';

/// Shared plumbing for the small "master data" lists (households, visarjan
/// groups, sponsors): a polled read of GET /api/<path> and POST/PUT writes.
/// Permissions are enforced by the server; the repositories only pre-check
/// them so the UI can fail fast.
abstract class MasterDataRepository<T> {
  MasterDataRepository(this._api, this._path, this._fromMap);

  final ApiClient _api;
  final String _path;
  final T Function(String id, Map<String, dynamic> m) _fromMap;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  static const pollInterval = Duration(minutes: 5);

  Future<List<T>> fetch() async {
    final json = await _api.get(_path);
    final items = (json['items'] as List?) ?? const [];
    return [
      for (final raw in items)
        _fromMap((raw as Map<String, dynamic>)['id'] as String, raw),
    ];
  }

  /// Master data changes rarely: polled every 5 minutes and re-read right
  /// after any local save.
  Stream<List<T>> watchList({int Function(T a, T b)? sort}) => pollStream<List<T>>(
        load: () async {
          final list = await fetch();
          if (sort != null) list.sort(sort);
          return list;
        },
        every: pollInterval,
        refreshes: _changed.stream,
      );

  Future<String> createItem(Map<String, dynamic> body) async {
    try {
      final json = await _api.post(_path, body: body);
      _changed.add(null);
      return (json['item'] as Map<String, dynamic>)['id'] as String;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateItem(String id, Map<String, dynamic> body) async {
    try {
      await _api.put('$_path/$id', body: body);
      _changed.add(null);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
