import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/domain/entry_validator.dart';

/// Result of [EntityDialog]: whatever id [EntityDialog.onSubmit] returned.
typedef EntitySubmit = Future<String?> Function(
  String name,
  String? notes,
  String? contact,
  bool active,
);

/// Add/edit dialog shared by households, visarjan groups and sponsors:
/// name (required, unique), optional notes, optional contact, active toggle.
class EntityDialog extends ConsumerStatefulWidget {
  const EntityDialog({
    super.key,
    required this.title,
    required this.existingNames,
    required this.onSubmit,
    this.initialName,
    this.initialNotes,
    this.initialContact,
    this.initialActive = true,
    this.withContact = false,
    this.withActiveToggle = false,
  });

  final String title;

  /// Names already in use (for the duplicate check).
  final List<String> existingNames;
  final EntitySubmit onSubmit;
  final String? initialName;
  final String? initialNotes;
  final String? initialContact;
  final bool initialActive;
  final bool withContact;
  final bool withActiveToggle;

  @override
  ConsumerState<EntityDialog> createState() => _EntityDialogState();
}

class _EntityDialogState extends ConsumerState<EntityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _contact;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _notes = TextEditingController(text: widget.initialNotes ?? '');
    _contact = TextEditingController(text: widget.initialContact ?? '');
    _active = widget.initialActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.onSubmit(
        _name.text,
        _notes.text,
        widget.withContact ? _contact.text : null,
        _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(id ?? '');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = describeError(ref.read(l10nProvider), e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: AppConstants.maxNameLength,
                decoration: InputDecoration(labelText: l.t('name')),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return l.t('v_required');
                  if (EntryValidator.isDuplicateName(
                    widget.existingNames,
                    value,
                    exceptName: widget.initialName,
                  )) {
                    return l.t('v_duplicate_name');
                  }
                  return null;
                },
              ),
              if (widget.withContact) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contact,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: l.t('contact_optional')),
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                maxLength: AppConstants.maxNotesLength,
                decoration: InputDecoration(labelText: l.t('notes_optional')),
              ),
              if (widget.withActiveToggle)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.t('active')),
                  value: _active,
                  onChanged: _saving ? null : (v) => setState(() => _active = v),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.t('cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.t('save')),
        ),
      ],
    );
  }
}

/// Opens [EntityDialog]. Returns the id produced by `onSubmit`, or null when
/// the dialog was cancelled.
Future<String?> showEntityDialog(
  BuildContext context, {
  required String title,
  required List<String> existingNames,
  required EntitySubmit onSubmit,
  String? initialName,
  String? initialNotes,
  String? initialContact,
  bool initialActive = true,
  bool withContact = false,
  bool withActiveToggle = false,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => EntityDialog(
      title: title,
      existingNames: existingNames,
      onSubmit: onSubmit,
      initialName: initialName,
      initialNotes: initialNotes,
      initialContact: initialContact,
      initialActive: initialActive,
      withContact: withContact,
      withActiveToggle: withActiveToggle,
    ),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}
