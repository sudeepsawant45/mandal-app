import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: LoadingState());
}

/// The saved session could not be checked (usually: no network). The session
/// is kept, so the user can retry, or sign out.
class ProfileErrorScreen extends ConsumerWidget {
  const ProfileErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: ErrorState(error: error)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ref.read(sessionProvider.notifier).restore(),
                      child: Text(l.t('retry')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref.read(authRepositoryProvider).signOut(),
                      child: Text(l.t('logout')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
