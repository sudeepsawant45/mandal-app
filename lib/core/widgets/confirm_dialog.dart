import 'package:flutter/material.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';

/// [confirmAction] with the standard confirm/cancel labels from [l10n].
Future<bool> confirmWith(
  BuildContext context,
  L10n l10n, {
  required String title,
  required String message,
  String confirmKey = 'confirm',
  bool destructive = true,
}) {
  return confirmAction(
    context,
    title: title,
    message: message,
    confirmLabel: l10n.t(confirmKey),
    cancelLabel: l10n.t('cancel'),
    destructive: destructive,
  );
}

/// Asks the user to confirm an action. Returns true only on explicit
/// confirmation; dismissing the dialog counts as "no".
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
