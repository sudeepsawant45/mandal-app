import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';
import 'package:ganpati_mandal/core/widgets/confirm_dialog.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/audit/audit_screen.dart';
import 'package:ganpati_mandal/features/settings/settings_screen.dart';
import 'package:ganpati_mandal/features/users/users_screen.dart';

/// My profile: the signed-in member exactly as the server reports them.
///
/// There is deliberately NO "edit profile" form: the backend has no endpoint
/// with which a member can change their own name or email (only an admin can
/// manage members, via /api/users). Showing a form that cannot save would
/// pretend something happened, so the screen is read-only and says why.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l = ref.read(l10nProvider);
    final ok = await confirmWith(
      context,
      l,
      title: l.t('logout'),
      message: l.t('logout_confirm'),
      confirmKey: 'logout',
      destructive: false,
    );
    if (!ok) return;
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(roleProvider);

    Widget nav(IconData icon, String label, Widget screen) => ListTile(
          leading: Icon(icon, color: AppTheme.royalBlue),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
        );

    final adminTiles = <Widget>[
      if (Permissions.canManageUsers(role)) nav(Icons.people_outline, l.t('users'), const UsersScreen()),
      if (Permissions.canConfigureSettings(role))
        nav(Icons.tune, l.t('mandal_settings'), const SettingsScreen()),
      if (Permissions.canViewAudit(role)) nav(Icons.history, l.t('audit_log'), const AuditScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.t('my_profile'))),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        InitialsAvatar(name: user.label, radius: 44),
                        const SizedBox(height: 12),
                        Text(
                          user.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        RoleBadge(role: role, l10n: l),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(l.t('name')),
                        subtitle: Text(user.displayName.isEmpty ? '—' : user.displayName),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.mail_outline),
                        title: Text(l.t('email')),
                        subtitle: Text(user.email),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: Text(l.t('account_status')),
                        trailing: StatusPill(
                          label: user.active ? l.t('active') : l.t('inactive'),
                          color: user.active ? FundColors.income : FundColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    l.t('profile_readonly_note'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SectionHeader(l.t('language')),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<String>(value: 'mr', label: Text('मराठी')),
                          ButtonSegment<String>(value: 'en', label: Text('English')),
                        ],
                        selected: {l.lang},
                        onSelectionChanged: (s) =>
                            ref.read(languageProvider.notifier).state = s.first,
                      ),
                    ),
                  ),
                ),
                if (adminTiles.isNotEmpty) ...[
                  SectionHeader(l.t('admin_tools')),
                  Card(child: Column(children: adminTiles)),
                ],
                SectionHeader(l.t('security')),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l.t('session_info')),
                  ),
                ),
                SectionHeader(l.t('about')),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l.t('app_name')),
                    subtitle: Text('${l.t('app_version')}: ${AppConstants.appVersion}'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FundColors.expense,
                      side: const BorderSide(color: FundColors.expense),
                    ),
                    onPressed: () => _logout(context, ref),
                    icon: const Icon(Icons.logout),
                    label: Text(l.t('logout')),
                  ),
                ),
              ],
            ),
    );
  }
}
