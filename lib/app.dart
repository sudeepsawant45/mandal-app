import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/features/auth/auth_gate.dart';

/// Root widget. Marathi is the default language; English is selectable from
/// the login screen or the app menu.
class MandalApp extends ConsumerWidget {
  const MandalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return MaterialApp(
      title: 'Ganpati Mandal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: Locale(lang),
      supportedLocales: const [Locale('mr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
