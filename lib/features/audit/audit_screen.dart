import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/models/audit_entry.dart';

/// Read-only list of the latest audit-trail entries (who changed what, when).
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  IconData _icon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'restore':
        return Icons.restore;
      case 'role_change':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final audit = ref.watch(auditProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('audit_log'))),
      body: AsyncValueView<List<AuditEntry>>(
        value: audit,
        builder: (list) {
          if (list.isEmpty) return EmptyState(message: l.t('no_audit'), icon: Icons.history);
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              return Card(
                child: ListTile(
                  leading: IconBadge(icon: _icon(a.action), color: AppTheme.royalBlue, size: 40),
                  title: Text(a.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${a.userName} • ${a.at == null ? '' : formatDateTime(a.at!)}',
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
