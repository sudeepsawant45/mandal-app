import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/widgets/confirm_dialog.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/audit/audit_screen.dart';
import 'package:ganpati_mandal/features/settings/settings_screen.dart';
import 'package:ganpati_mandal/features/users/users_screen.dart';

enum _MenuAction { language, users, settings, audit, logout }

/// Overflow menu shown on every top-level screen: language, admin tools, logout.
class AppMenuButton extends ConsumerWidget {
  const AppMenuButton({super.key});

  Widget _item(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Flexible(child: Text(label)),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final actor = ref.watch(actorProvider);
    final role = ref.watch(roleProvider);

    return PopupMenuButton<_MenuAction>(
      tooltip: l.t('menu'),
      onSelected: (action) async {
        switch (action) {
          case _MenuAction.language:
            ref.read(languageProvider.notifier).state = l.isMarathi ? 'en' : 'mr';
          case _MenuAction.users:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const UsersScreen()),
            );
          case _MenuAction.settings:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          case _MenuAction.audit:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AuditScreen()),
            );
          case _MenuAction.logout:
            final ok = await confirmWith(
              context,
              l,
              title: l.t('logout'),
              message: l.t('logout_confirm'),
              confirmKey: 'logout',
              destructive: false,
            );
            if (ok) await ref.read(authRepositoryProvider).signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<_MenuAction>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(actor?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(l.role(role), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.language,
          child: _item(Icons.language, l.isMarathi ? 'English' : 'मराठी'),
        ),
        if (Permissions.canManageUsers(role))
          PopupMenuItem<_MenuAction>(
            value: _MenuAction.users,
            child: _item(Icons.people_outline, l.t('users')),
          ),
        if (Permissions.canConfigureSettings(role))
          PopupMenuItem<_MenuAction>(
            value: _MenuAction.settings,
            child: _item(Icons.settings_outlined, l.t('settings')),
          ),
        if (Permissions.canViewAudit(role))
          PopupMenuItem<_MenuAction>(
            value: _MenuAction.audit,
            child: _item(Icons.history, l.t('audit_log')),
          ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logout,
          child: _item(Icons.logout, l.t('logout')),
        ),
      ],
    );
  }
}
