import 'package:ganpati_mandal/core/utils/date_utils.dart';

/// A household or group that conducts its own visarjan (separate account).
class VisarjanGroup {
  const VisarjanGroup({
    required this.id,
    required this.name,
    this.notes,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? notes;
  final bool active;
  final DateTime? createdAt;

  factory VisarjanGroup.fromMap(String id, Map<String, dynamic> m) => VisarjanGroup(
        id: id,
        name: (m['name'] as String?) ?? '',
        notes: m['notes'] as String?,
        active: (m['active'] as bool?) ?? true,
        createdAt: readDate(m['createdAt']),
      );
}
