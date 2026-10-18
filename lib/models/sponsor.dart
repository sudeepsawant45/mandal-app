import 'package:ganpati_mandal/core/utils/date_utils.dart';

/// A T-shirt sponsor (person or business).
class Sponsor {
  const Sponsor({
    required this.id,
    required this.name,
    this.contact,
    this.notes,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? contact;
  final String? notes;
  final bool active;
  final DateTime? createdAt;

  factory Sponsor.fromMap(String id, Map<String, dynamic> m) => Sponsor(
        id: id,
        name: (m['name'] as String?) ?? '',
        contact: m['contact'] as String?,
        notes: m['notes'] as String?,
        active: (m['active'] as bool?) ?? true,
        createdAt: readDate(m['createdAt']),
      );
}
