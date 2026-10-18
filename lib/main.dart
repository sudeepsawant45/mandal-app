import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // No Firebase setup is needed on the device: the app only talks to the
  // mandal's API (see --dart-define=API_BASE_URL in README.md).
  runApp(const ProviderScope(child: MandalApp()));
}
