import 'package:flutter/material.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';

/// Shown to viewers so it is obvious the app is read-only for them.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key, required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.t('viewer_read_only'),
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
