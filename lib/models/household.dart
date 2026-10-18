import 'package:ganpati_mandal/core/utils/date_utils.dart';

/// A household that celebrates Ganpati at home and may donate several times.
class Household {
  const Household({
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

  factory Household.fromMap(String id, Map<String, dynamic> m) => Household(
        id: id,
        name: (m['name'] as String?) ?? '',
        notes: m['notes'] as String?,
        active: (m['active'] as bool?) ?? true,
        createdAt: readDate(m['createdAt']),
      );
}
