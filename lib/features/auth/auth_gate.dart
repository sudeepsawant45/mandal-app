import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/features/auth/account_screens.dart';
import 'package:ganpati_mandal/features/auth/login_screen.dart';
import 'package:ganpati_mandal/features/navigation/home_shell.dart';
import 'package:ganpati_mandal/services/session_controller.dart';

/// Decides what to show from the server-validated session:
///   restoring a saved session          -> splash
///   no / expired / revoked session      -> email-OTP login
///   could not reach the server          -> error screen with retry
///   valid session of an approved member -> the app
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    switch (session.status) {
      case SessionStatus.loading:
        return const SplashScreen();
      case SessionStatus.signedOut:
        return const LoginScreen();
      case SessionStatus.error:
        return ProfileErrorScreen(error: session.error ?? 'error');
      case SessionStatus.signedIn:
        return const HomeShell();
    }
  }
}
