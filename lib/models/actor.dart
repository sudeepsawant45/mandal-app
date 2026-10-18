import 'package:ganpati_mandal/models/app_enums.dart';

/// The signed-in, approved user performing a write. Passed to repositories so
/// they can stamp created-by / updated-by / audit information.
class Actor {
  const Actor({required this.uid, required this.name, required this.role});

  final String uid;
  final String name;
  final AppRole role;
}
