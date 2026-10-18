import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/core/utils/money.dart';
import 'package:ganpati_mandal/core/utils/text_utils.dart';
import 'package:ganpati_mandal/core/widgets/confirm_dialog.dart';
import 'package:ganpati_mandal/core/widgets/entity_dialog.dart';
import 'package:ganpati_mandal/core/widgets/form_fields.dart';
import 'package:ganpati_mandal/domain/categories.dart';
import 'package:ganpati_mandal/domain/entry_validator.dart';
import 'package:ganpati_mandal/domain/permissions.dart';
import 'package:ganpati_mandal/features/ledger/ledger_labels.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';
import 'package:uuid/uuid.dart';

/// Pushes the add/edit form for [fund].
Future<bool?> openEntryForm(
  BuildContext context,
  Fund fund, {
  TxnType? initialType,
  String? presetGroupId,
  String? presetHouseholdId,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => EntryFormScreen(
        fund: fund,
        initialType: initialType,
        presetGroupId: presetGroupId,
        presetHouseholdId: presetHouseholdId,
      ),
    ),
  );
}

/// One form for all four funds. Only the fields that belong to the fund are
/// shown and written, so an entry can never carry another fund's references.
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.fund,
    this.existing,
    this.initialType,
    this.presetGroupId,
    this.presetHouseholdId,
  });

  final Fund fund;

  /// Set when editing.
  final LedgerEntry? existing;
  final TxnType? initialType;
  final String? presetGroupId;
  final String? presetHouseholdId;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Generated once per form instance: a double tap or a retry re-uses the
  /// same id, so the repository can recognise (and ignore) a repeat.
  late final String _entryId;

  late TxnType _type;
  late DateTime _date;
  String? _householdId;
  String? _groupId;
  String? _sponsorId;
  String? _category;
  String? _paymentMethod;

  final _amount = TextEditingController();
  final _contributor = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _quantity = TextEditingController();

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _entryId = e?.id ?? const Uuid().v4();
    final allowed = Categories.allowedTypes(widget.fund);
    _type = e?.type ??
        (widget.initialType != null && allowed.contains(widget.initialType)
            ? widget.initialType!
            : allowed.first);
    _date = e?.date ?? dateOnly(DateTime.now());
    _householdId = e?.householdId ?? widget.presetHouseholdId;
    _groupId = e?.visarjanGroupId ?? widget.presetGroupId;
    _sponsorId = e?.sponsorId;
    _category = e?.category;
    _paymentMethod = e?.paymentMethod;
    if (e != null) {
      _amount.text = Money.toInputText(e.amountPaise);
      _contributor.text = e.contributorName ?? '';
      _description.text = e.description;
      _notes.text = e.notes ?? '';
      _quantity.text = e.quantity?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _contributor.dispose();
    _description.dispose();
    _notes.dispose();
    _quantity.dispose();
    super.dispose();
  }

  // Which fields apply to this fund / direction.
  bool get _isIncome => _type == TxnType.income;
  bool get _showHousehold => widget.fund == Fund.householdDonation;
  bool get _showGroup => widget.fund == Fund.visarjan;
  bool get _showSponsor => widget.fund == Fund.tshirtSponsorship && _isIncome;
  bool get _showContributor =>
      widget.fund == Fund.householdDonation || (widget.fund == Fund.visarjan && _isIncome);
  bool get _showMethod =>
      widget.fund == Fund.householdDonation ||
      (_isIncome &&
          (widget.fund == Fund.visarjan || widget.fund == Fund.tshirtSponsorship));
  bool get _methodRequired => widget.fund == Fund.householdDonation;
  bool get _showCategory => widget.fund == Fund.commonMandal;
  bool get _descriptionRequired => widget.fund == Fund.commonMandal || !_isIncome;
  bool get _showQuantity => widget.fund == Fund.tshirtSponsorship && !_isIncome;

  String _categoryValue() {
    final options = Categories.optionsFor(widget.fund, _type);
    return (_category != null && options.contains(_category)) ? _category! : options.first;
  }

  LedgerEntry _buildEntry(Actor actor) {
    final e = widget.existing;
    final households = ref.read(householdsProvider).valueOrNull ?? const <Household>[];
    final groups = ref.read(visarjanGroupsProvider).valueOrNull ?? const <VisarjanGroup>[];
    final sponsors = ref.read(sponsorsProvider).valueOrNull ?? const <Sponsor>[];

    String? householdName;
    if (_showHousehold && _householdId != null) {
      householdName = households.where((h) => h.id == _householdId).map((h) => h.name).firstOrNull;
    }
    String? groupName;
    if (_showGroup && _groupId != null) {
      groupName = groups.where((g) => g.id == _groupId).map((g) => g.name).firstOrNull;
    }
    String? sponsorName;
    if (_showSponsor && _sponsorId != null) {
      sponsorName = sponsors.where((s) => s.id == _sponsorId).map((s) => s.name).firstOrNull;
    }

    var description = _description.text.trim();
    if (description.isEmpty) {
      description = Categories.defaultDescription(widget.fund, _type) ?? '';
    }

    final quantityText = _quantity.text.trim();

    return LedgerEntry(
      id: _entryId,
      fund: widget.fund,
      type: _type,
      amountPaise: Money.parseToPaise(_amount.text) ?? 0,
      date: dateOnly(_date),
      description: description,
      category: _categoryValue(),
      createdBy: e?.createdBy ?? actor.uid,
      createdByName: e?.createdByName ?? actor.name,
      createdAt: e?.createdAt ?? DateTime.now(),
      householdId: _showHousehold ? _householdId : null,
      householdName: _showHousehold ? householdName : null,
      visarjanGroupId: _showGroup ? _groupId : null,
      visarjanGroupName: _showGroup ? groupName : null,
      sponsorId: _showSponsor ? _sponsorId : null,
      sponsorName: _showSponsor ? sponsorName : null,
      contributorName: _showContributor ? cleanOrNull(_contributor.text) : null,
      paymentMethod: _showMethod ? _paymentMethod : null,
      notes: cleanOrNull(_notes.text),
      quantity: (_showQuantity && quantityText.isNotEmpty) ? int.tryParse(quantityText) : null,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = ref.read(l10nProvider);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final actor = ref.read(actorProvider);
    if (actor == null) return;

    final entry = _buildEntry(actor);
    final issues = EntryValidator.validate(entry);
    if (issues.isNotEmpty) {
      _showMessage(l.t(issues.first.messageKey));
      return;
    }

    if (!_isEdit) {
      final all = ref.read(allEntriesProvider).valueOrNull ?? const <LedgerEntry>[];
      if (EntryValidator.isLikelyDuplicate(entry, all, now: DateTime.now())) {
        final proceed = await confirmWith(
          context,
          l,
          title: l.t('duplicate_title'),
          message: l.t('duplicate_message'),
          confirmKey: 'save_anyway',
          destructive: false,
        );
        if (!proceed || !mounted) return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      final existing = widget.existing;
      if (existing != null) {
        await repo.update(existing, entry, actor);
      } else {
        await repo.create(entry, actor);
      }
      if (!mounted) return;
      _showMessage(l.t('saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(describeError(l, e));
    }
  }

  Future<void> _addGroup() async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    final groups = ref.read(visarjanGroupsProvider).valueOrNull ?? const <VisarjanGroup>[];
    final id = await showEntityDialog(
      context,
      title: l.t('add_group'),
      existingNames: groups.map((g) => g.name).toList(),
      onSubmit: (name, notes, contact, active) => ref
          .read(visarjanRepositoryProvider)
          .add(name: name, notes: notes, actor: actor),
    );
    if (id != null && mounted) setState(() => _groupId = id);
  }

  Future<void> _addSponsor() async {
    final l = ref.read(l10nProvider);
    final actor = ref.read(actorProvider);
    if (actor == null) return;
    final sponsors = ref.read(sponsorsProvider).valueOrNull ?? const <Sponsor>[];
    final id = await showEntityDialog(
      context,
      title: l.t('add_sponsor'),
      withContact: true,
      existingNames: sponsors.map((s) => s.name).toList(),
      onSubmit: (name, notes, contact, active) => ref
          .read(sponsorRepositoryProvider)
          .add(name: name, contact: contact, notes: notes, actor: actor),
    );
    if (id != null && mounted) setState(() => _sponsorId = id);
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final role = ref.watch(roleProvider);
    final fund = widget.fund;
    final color = FundColors.of(fund);

    final households = ref.watch(householdsProvider).valueOrNull ?? const <Household>[];
    final groups = ref.watch(visarjanGroupsProvider).valueOrNull ?? const <VisarjanGroup>[];
    final sponsors = ref.watch(sponsorsProvider).valueOrNull ?? const <Sponsor>[];

    final allowedTypes = Categories.allowedTypes(fund);
    final categoryOptions = Categories.optionsFor(fund, _type);

    final householdItems = [
      for (final h in households)
        if (h.active || h.id == _householdId)
          DropdownMenuItem<String>(value: h.id, child: Text(h.name)),
    ];
    final groupItems = [
      for (final g in groups)
        if (g.active || g.id == _groupId)
          DropdownMenuItem<String>(value: g.id, child: Text(g.name)),
    ];
    final sponsorItems = [
      for (final s in sponsors)
        if (s.active || s.id == _sponsorId)
          DropdownMenuItem<String>(value: s.id, child: Text(s.name)),
    ];

    final lockedGroup = widget.presetGroupId != null && !_isEdit;
    final canAddGroups = Permissions.canManageGroupsAndSponsors(role);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.t('edit_entry') : l.t('add_entry')),
        backgroundColor: color.withValues(alpha: 0.15),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.fund(fund),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (allowedTypes.length > 1)
              SegmentedButton<TxnType>(
                segments: [
                  for (final t in allowedTypes)
                    ButtonSegment<TxnType>(
                      value: t,
                      label: Text(entryTypeLabel(l, fund, t)),
                    ),
                ],
                selected: {_type},
                // The direction of an existing entry never changes (fund and
                // type are immutable; correct a wrong one by deleting and
                // re-entering).
                onSelectionChanged: _isEdit
                    ? null
                    : (s) => setState(() {
                          _type = s.first;
                          _category = null;
                        }),
              ),
            if (allowedTypes.length > 1) const SizedBox(height: 16),

            if (_showHousehold) ...[
              AppDropdown<String>(
                label: l.t('household'),
                value: _householdId,
                items: householdItems,
                onChanged: (v) => setState(() => _householdId = v),
                validator: (v) => v == null ? l.t('v_required') : null,
              ),
              if (households.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.t('no_households_hint'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            if (_showGroup) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppDropdown<String>(
                      label: l.t('group'),
                      value: _groupId,
                      items: groupItems,
                      enabled: !lockedGroup,
                      onChanged: (v) => setState(() => _groupId = v),
                      validator: (v) => v == null ? l.t('v_required') : null,
                    ),
                  ),
                  if (!lockedGroup && canAddGroups)
                    IconButton(
                      tooltip: l.t('add_group'),
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _addGroup,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_showSponsor) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppDropdown<String>(
                      label: l.t('sponsor'),
                      value: _sponsorId,
                      items: sponsorItems,
                      onChanged: (v) => setState(() => _sponsorId = v),
                      validator: (v) => v == null ? l.t('v_required') : null,
                    ),
                  ),
                  if (canAddGroups)
                    IconButton(
                      tooltip: l.t('add_sponsor'),
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _addSponsor,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_showContributor) ...[
              TextFormField(
                controller: _contributor,
                textCapitalization: TextCapitalization.words,
                maxLength: AppConstants.maxNameLength,
                decoration: InputDecoration(labelText: l.t('contributor')),
                validator: (v) => (v ?? '').trim().isEmpty ? l.t('v_required') : null,
              ),
              const SizedBox(height: 8),
            ],

            AmountFormField(controller: _amount, l10n: l),
            const SizedBox(height: 16),

            DateFormField(
              l10n: l,
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 16),

            if (_showCategory) ...[
              AppDropdown<String>(
                label: l.t('category'),
                value: _categoryValue(),
                items: [
                  for (final c in categoryOptions)
                    DropdownMenuItem<String>(value: c, child: Text(l.category(c))),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 16),
            ],

            if (_showMethod) ...[
              AppDropdown<String>(
                label: _methodRequired ? l.t('method') : l.t('method_optional'),
                value: _paymentMethod,
                items: [
                  for (final m in PaymentMethod.values)
                    DropdownMenuItem<String>(value: m.value, child: Text(l.paymentMethod(m.value))),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v),
                validator: _methodRequired
                    ? (v) => v == null ? l.t('v_required') : null
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _description,
              maxLength: AppConstants.maxDescriptionLength,
              decoration: InputDecoration(
                labelText: _descriptionRequired ? l.t('description') : l.t('description_optional'),
              ),
              validator: _descriptionRequired
                  ? (v) => (v ?? '').trim().isEmpty ? l.t('v_required') : null
                  : null,
            ),
            const SizedBox(height: 8),

            if (_showQuantity) ...[
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.t('quantity_optional')),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final n = int.tryParse(t);
                  if (n == null || n <= 0 || n > AppConstants.maxQuantity) {
                    return l.t('v_quantity_positive');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _notes,
              maxLines: 2,
              maxLength: AppConstants.maxNotesLength,
              decoration: InputDecoration(labelText: l.t('notes_optional')),
            ),
            const SizedBox(height: 16),

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
      ),
    );
  }
}
