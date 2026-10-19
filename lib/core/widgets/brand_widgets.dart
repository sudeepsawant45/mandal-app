import 'package:flutter/material.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

/// Round emblem used on the welcome / login screens and the dashboard header.
/// It is drawn with text only (the Sanskrit "Om"): the project has no Ganpati
/// image asset. To use real artwork, put the image in assets/ and replace the
/// child of this widget.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 88, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark ? Colors.white : AppTheme.paleBlue,
        border: Border.all(color: AppTheme.gold, width: size / 24),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Text(
        'ॐ',
        style: TextStyle(
          fontSize: size * 0.5,
          height: 1.1,
          color: AppTheme.saffron,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Circle with the person's initials (no photo upload exists in the backend).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 22, this.inactive = false});

  final String name;
  final double radius;
  final bool inactive;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = String.fromCharCodes(parts.first.runes.take(1));
    if (parts.length == 1) return first.toUpperCase();
    final last = String.fromCharCodes(parts.last.runes.take(1));
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: inactive ? const Color(0xFFE0E0E0) : AppTheme.paleBlue,
      child: inactive
          ? Icon(Icons.block, size: radius, color: Colors.grey.shade600)
          : Text(
              initialsOf(name),
              style: TextStyle(
                color: AppTheme.royalBlue,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}

/// Small coloured pill showing a role.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, required this.l10n});

  final AppRole role;
  final L10n l10n;

  static Color colorOf(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const Color(0xFFC62828);
      case AppRole.committee:
        return const Color(0xFF1565C0);
      case AppRole.viewer:
        return const Color(0xFF2E7D32);
      case AppRole.pending:
        return const Color(0xFF8D6E63);
    }
  }

  @override
  Widget build(BuildContext context) => StatusPill(label: l10n.role(role), color: colorOf(role));
}

/// Generic tinted pill.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Section title used between groups of cards.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rounded pale-blue icon tile used for list leading widgets and shortcuts.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}
