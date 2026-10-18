import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/features/dashboard/dashboard_screen.dart';
import 'package:ganpati_mandal/features/households/donations_screen.dart';
import 'package:ganpati_mandal/features/mandal_fund/mandal_fund_screen.dart';
import 'package:ganpati_mandal/features/tshirt_sponsorship/tshirt_screen.dart';
import 'package:ganpati_mandal/features/visarjan/visarjan_screen.dart';

/// Bottom navigation: Home, Donations, Common fund, Visarjan, T-shirt.
/// Reports are reachable from the dashboard and from each section's app bar.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final index = ref.watch(homeTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          DashboardScreen(),
          DonationsScreen(),
          MandalFundScreen(),
          VisarjanScreen(),
          TshirtScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(homeTabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l.t('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.home_work_outlined),
            selectedIcon: const Icon(Icons.home_work),
            label: l.t('nav_donations'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l.t('nav_common'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.water_drop_outlined),
            selectedIcon: const Icon(Icons.water_drop),
            label: l.t('nav_visarjan'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.checkroom_outlined),
            selectedIcon: const Icon(Icons.checkroom),
            label: l.t('nav_tshirt'),
          ),
        ],
      ),
    );
  }
}
