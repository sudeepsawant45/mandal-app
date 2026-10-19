import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';

/// Six separate digit boxes backed by ONE hidden text field, so paste, SMS/e-mail
/// autofill and the keyboard all keep working. [controller] holds the digits.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
    this.autofocus = true,
  });

  static const length = 6;

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  /// Called once when all six digits have been entered.
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool hasError;
  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final scheme = Theme.of(context).colorScheme;
    final boxes = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < OtpCodeField.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == OtpCodeField.length - 1 ? 0 : 8),
              child: _box(
                context,
                digit: i < text.length ? text[i] : '',
                active: _focus.hasFocus && widget.enabled && i == text.length.clamp(0, 5),
                scheme: scheme,
              ),
            ),
          ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? () => _focus.requestFocus() : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(child: boxes),
          // The real input: invisible, but focusable and full-size.
          Positioned.fill(
            child: Opacity(
              opacity: 0.02,
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                maxLength: OtpCodeField.length,
                showCursor: false,
                enableInteractiveSelection: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorStyle: TextStyle(height: 0, fontSize: 0),
                ),
                validator: widget.validator,
                onChanged: (v) {
                  widget.onChanged?.call(v);
                  if (v.length == OtpCodeField.length) widget.onCompleted?.call(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(
    BuildContext context, {
    required String digit,
    required bool active,
    required ColorScheme scheme,
  }) {
    final borderColor = widget.hasError
        ? scheme.error
        : (active ? AppTheme.royalBlue : scheme.outlineVariant);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.enabled ? Colors.white : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(color: borderColor, width: active || widget.hasError ? 2 : 1),
      ),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textDark),
      ),
    );
  }
}
