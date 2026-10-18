import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Flutter app must hold no Gmail / SMTP credentials or server keys.
/// (Runs from the project root, as `flutter test` does.)
void main() {
  final forbidden = <RegExp>[
    RegExp(r'GMAIL_APP_PASSWORD', caseSensitive: false),
    RegExp(r'OTP_PEPPER', caseSensitive: false),
    RegExp(r'smtp\.gmail\.com', caseSensitive: false),
    RegExp(r'nodemailer', caseSensitive: false),
    RegExp(r'BEGIN (RSA |EC )?PRIVATE KEY'),
    RegExp(r'"private_key"\s*:'),
    RegExp(r'service[_-]?account', caseSensitive: false),
  ];

  List<File> filesUnder(String dir, Set<String> exts) {
    final d = Directory(dir);
    if (!d.existsSync()) return [];
    return d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => exts.any(f.path.endsWith))
        .toList();
  }

  test('client source (lib/, android/, test helpers) contains no server-side secrets', () {
    final files = [
      ...filesUnder('lib', {'.dart'}),
      ...filesUnder('android', {'.xml', '.gradle', '.kts', '.properties', '.json'}),
      File('pubspec.yaml'),
    ].where((f) => f.existsSync());
    expect(files, isNotEmpty);
    for (final f in files) {
      final text = f.readAsStringSync();
      for (final re in forbidden) {
        expect(re.hasMatch(text), isFalse, reason: '${f.path} matches ${re.pattern}');
      }
    }
  });

  test('the OTP is never generated or compared in Dart', () {
    for (final f in filesUnder('lib', {'.dart'})) {
      final text = f.readAsStringSync();
      expect(text.contains('Random.secure'), isFalse, reason: f.path);
      expect(RegExp(r'Random\(').hasMatch(text), isFalse, reason: f.path);
    }
  });

  test('the app contains no Firebase / Firestore code and does not depend on it', () {
    final banned = RegExp(
      r'package:(cloud_firestore|firebase_auth|firebase_core)|FirebaseFirestore|FirebaseAuth|DocumentSnapshot|signInWithCustomToken',
    );
    for (final f in filesUnder('lib', {'.dart'})) {
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dep in ['cloud_firestore', 'firebase_auth', 'firebase_core']) {
      expect(RegExp('^\\s+$dep:', multiLine: true).hasMatch(pubspec), isFalse, reason: dep);
    }
    // no google-services plugin / config is needed any more
    for (final f in filesUnder('android', {'.gradle', '.kts'})) {
      expect(f.readAsStringSync().contains('com.google.gms.google-services'), isFalse, reason: f.path);
    }
  });

  test('the session token is kept in secure storage, never in shared preferences', () {
    final store = File('lib/services/token_store.dart').readAsStringSync();
    expect(store.contains('flutter_secure_storage'), isTrue);
    for (final f in filesUnder('lib', {'.dart'})) {
      expect(f.readAsStringSync().contains('shared_preferences'), isFalse, reason: f.path);
    }
  });

  test('no password sign-in or registration code remains', () {
    for (final f in filesUnder('lib', {'.dart'})) {
      final text = f.readAsStringSync();
      expect(text.contains('signInWithEmailAndPassword'), isFalse, reason: f.path);
      expect(text.contains('createUserWithEmailAndPassword'), isFalse, reason: f.path);
    }
  });
}
