import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';
import 'package:ganpati_mandal/core/widgets/confirm_dialog.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/app_user.dart';

/// Admin-only: add approved members, change roles, activate / deactivate.
/// There is no self-registration. The server refuses anyone else access to this
/// data, and nobody can change their own role.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    AppRole newRole,
  ) async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null || newRole == user.role) return;
    final ok = await confirmWith(
      context,
      l,
      title: l.t('change_role_title'),
      message: '${user.label}: ${l.role(user.role)} → ${l.role(newRole)}',
      destructive: false,
    );
    if (!ok) return;
    try {
      await ref.read(userRepositoryProvider).setRole(
            target: user,
            newRole: newRole,
            actor: actor,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('saved'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(l, e))));
      }
    }
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, AppUser user) async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    final ok = await confirmWith(
      context,
      l,
      title: l.t(user.active ? 'deactivate_title' : 'activate_title'),
      message: user.label,
      destructive: user.active,
    );
    if (!ok) return;
    try {
      await ref.read(userRepositoryProvider).setActive(
            target: user,
            active: !user.active,
            actor: actor,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(l, e))));
      }
    }
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    final email = TextEditingController();
    final name = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var role = AppRole.viewer;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.t('add_member')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l.t('your_name')),
                  validator: (v) => (v ?? '').trim().isEmpty ? l.t('v_required') : null,
                ),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l.t('email')),
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                      ? null
                      : l.t('v_email_invalid'),
                ),
                const SizedBox(height: 12),
                DropdownButton<AppRole>(
                  value: role,
                  isExpanded: true,
                  items: [
                    for (final r in _assignableRoles)
                      DropdownMenuItem<AppRole>(value: r, child: Text(l.role(r))),
                  ],
                  onChanged: (r) => setState(() => role = r ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.t('cancel'))),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
              },
              child: Text(l.t('save')),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await ref.read(userRepositoryProvider).createMember(
            email: email.text,
            displayName: name.text,
            role: role,
            actor: actor,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('saved'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(l, e))));
      }
    }
  }

  static const _assignableRoles = [AppRole.admin, AppRole.committee, AppRole.viewer];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final me = ref.watch(actorProvider);
    final users = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('users'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMember(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l.t('add_member')),
      ),
      body: AsyncValueView<List<AppUser>>(
        value: users,
        builder: (list) {
          if (list.isEmpty) return EmptyState(message: l.t('no_users'));
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final u = list[i];
              final isMe = me != null && u.uid == me.uid;
              final inactive = !u.active;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      InitialsAvatar(name: u.label, inactive: inactive),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            Text(
                              u.email,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                RoleBadge(role: u.role, l10n: l),
                                if (inactive)
                                  StatusPill(label: l.t('inactive'), color: FundColors.expense),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isMe)
                        PopupMenuButton<Object>(
                          tooltip: l.t('menu'),
                          onSelected: (v) {
                            if (v is AppRole) {
                              _changeRole(context, ref, u, v);
                            } else {
                              _toggleActive(context, ref, u);
                            }
                          },
                          itemBuilder: (_) => [
                            for (final r in _assignableRoles)
                              CheckedPopupMenuItem<Object>(
                                value: r,
                                checked: r == u.role,
                                child: Text(l.role(r)),
                              ),
                            const PopupMenuDivider(),
                            PopupMenuItem<Object>(
                              value: 'toggle',
                              child: Text(l.t(inactive ? 'activate_title' : 'deactivate_title')),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
