import 'package:flutter_test/flutter_test.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/app_user.dart';

void main() {
  group('AppUser approval', () {
    AppUser user(Map<String, dynamic> m) => AppUser.fromMap('id1', {'email': 'a@x.com', ...m});

    test('approved only when role is real AND active == true', () {
      expect(user({'role': 'admin', 'active': true}).isApproved, isTrue);
      expect(user({'role': 'committee', 'active': true}).isApproved, isTrue);
      expect(user({'role': 'viewer', 'active': true}).isApproved, isTrue);
    });
    test('inactive, missing flag, pending or unknown role are not approved (fail closed)', () {
      expect(user({'role': 'admin', 'active': false}).isApproved, isFalse);
      expect(user({'role': 'admin'}).isApproved, isFalse);
      expect(user({'role': 'pending', 'active': true}).isApproved, isFalse);
      expect(user({'role': 'superuser', 'active': true}).isApproved, isFalse);
      expect(user({'role': 'admin', 'active': 'true'}).isApproved, isFalse);
    });
    test('unknown role strings parse as pending', () {
      expect(user({'role': 'x', 'active': true}).role, AppRole.pending);
    });
  });
}
