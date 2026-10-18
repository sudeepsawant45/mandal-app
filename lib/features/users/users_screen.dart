import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
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
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = list[i];
              final isMe = me != null && u.uid == me.uid;
              final inactive = !u.active;
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(inactive ? Icons.block : Icons.person_outline),
                ),
                title: Text(u.label),
                subtitle: Text(inactive ? '${u.email}\n${l.t('inactive')}' : u.email),
                isThreeLine: inactive,
                trailing: isMe
                    ? Text(l.role(u.role))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<AppRole>(
                            value: _assignableRoles.contains(u.role) ? u.role : null,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final r in _assignableRoles)
                                DropdownMenuItem<AppRole>(value: r, child: Text(l.role(r))),
                            ],
                            onChanged: (r) {
                              if (r != null) _changeRole(context, ref, u, r);
                            },
                          ),
                          IconButton(
                            tooltip: l.t(inactive ? 'activate_title' : 'deactivate_title'),
                            icon: Icon(inactive ? Icons.check_circle_outline : Icons.block),
                            onPressed: () => _toggleActive(context, ref, u),
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
