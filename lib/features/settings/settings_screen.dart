import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/widgets/state_views.dart';
import 'package:ganpati_mandal/models/mandal_settings.dart';

/// Admin-only: mandal name and financial year printed on every report.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: AsyncValueView<MandalSettings>(
        value: settings,
        builder: (s) => _SettingsForm(settings: s),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});

  final MandalSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _year;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.settings.mandalName);
    _year = TextEditingController(text: widget.settings.financialYear);
  }

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).save(
            mandalName: _name.text,
            financialYear: _year.text,
            previous: widget.settings,
            actor: actor,
          );
      messenger.showSnackBar(SnackBar(content: Text(l.t('saved'))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.settings.configured)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l.t('settings_not_configured')),
            ),
          TextFormField(
            controller: _name,
            maxLength: AppConstants.maxNameLength,
            decoration: InputDecoration(labelText: l.t('mandal_name')),
            validator: (v) => (v ?? '').trim().isEmpty ? l.t('v_required') : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _year,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: l.t('financial_year'),
              hintText: '2026-27',
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? l.t('v_required') : null,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(l.t('save')),
          ),
        ],
      ),
    );
  }
}
