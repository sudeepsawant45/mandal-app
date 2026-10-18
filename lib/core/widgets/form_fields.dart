import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ganpati_mandal/core/constants/app_constants.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/utils/date_utils.dart';
import 'package:ganpati_mandal/core/utils/money.dart';

/// Rupee amount input. Validates with [Money.parseToPaise]; no floating point.
class AmountFormField extends StatelessWidget {
  const AmountFormField({
    super.key,
    required this.controller,
    required this.l10n,
    this.label,
    this.enabled = true,
  });

  final TextEditingController controller;
  final L10n l10n;
  final String? label;
  final bool enabled;

  /// Shared validator (also used directly in tests).
  static String? validate(L10n l10n, String? value) {
    final paise = Money.parseToPaise(value);
    if (paise == null) return l10n.t('v_amount_invalid');
    if (paise <= 0) return l10n.t('v_amount_positive');
    if (paise > AppConstants.maxAmountPaise) return l10n.t('v_amount_too_large');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9०-९.,]')),
      ],
      decoration: InputDecoration(
        labelText: label ?? l10n.t('amount'),
        prefixText: '${Money.rupeeSymbol} ',
      ),
      validator: (v) => validate(l10n, v),
    );
  }
}

/// Date picker field backed by a [FormField] so it takes part in validation.
class DateFormField extends FormField<DateTime> {
  // `enabled` is used inside the builder closure, so it cannot become a super parameter.
  // ignore: use_super_parameters
  DateFormField({
    super.key,
    required L10n l10n,
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
    String? label,
    bool enabled = true,
  }) : super(
          initialValue: value,
          enabled: enabled,
          validator: (v) => v == null ? l10n.t('v_required') : null,
          builder: (state) {
            return InkWell(
              onTap: !enabled
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: state.context,
                        initialDate: state.value ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        state.didChange(picked);
                        onChanged(picked);
                      }
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: label ?? l10n.t('date'),
                  errorText: state.errorText,
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                ),
                child: Text(state.value == null ? '' : formatDate(state.value!)),
              ),
            );
          },
        );
}

/// Dropdown that works as a form field without relying on the
/// `DropdownButtonFormField.value` parameter (deprecated in recent Flutter).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Keyed on the value so the inner FormField picks up programmatic changes
    // (e.g. a freshly created sponsor being selected).
    return FormField<T>(
      key: ValueKey<Object?>(value),
      initialValue: value,
      validator: validator,
      enabled: enabled,
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(labelText: label, errorText: state.errorText),
          isEmpty: state.value == null,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              isDense: true,
              value: state.value,
              items: items,
              onChanged: enabled
                  ? (v) {
                      state.didChange(v);
                      onChanged(v);
                    }
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// Date-range filter button with a clear icon.
class DateRangeFilter extends StatelessWidget {
  const DateRangeFilter({
    super.key,
    required this.l10n,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final L10n l10n;
  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;

  @override
  Widget build(BuildContext context) {
    final label = periodText(
      from,
      to,
      allLabel: l10n.t('all_dates'),
      fromWord: l10n.t('from_word'),
      untilWord: l10n.t('until_word'),
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(label, overflow: TextOverflow.ellipsis),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDateRange: (from != null && to != null)
                    ? DateTimeRange(start: from!, end: to!)
                    : null,
              );
              if (picked != null) onChanged(dateOnly(picked.start), dateOnly(picked.end));
            },
          ),
        ),
        if (from != null || to != null)
          IconButton(
            tooltip: l10n.t('clear'),
            icon: const Icon(Icons.clear),
            onPressed: () => onChanged(null, null),
          ),
      ],
    );
  }
}
