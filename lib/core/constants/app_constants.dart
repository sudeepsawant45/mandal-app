/// Business-rule constants. The numeric limits are mirrored in backend/src/validation.js (the server enforces them).
class AppConstants {
  AppConstants._();

  /// A committee member may edit / soft-delete only entries they created,
  /// and only within this window. Admins are not limited.
  static const committeeEditWindow = Duration(days: 7);

  /// Upper bound for one entry: Rs 100 crore, in paise.
  static const maxAmountPaise = 100000000000;

  static const maxNameLength = 100;
  static const maxDescriptionLength = 200;
  static const maxCategoryLength = 50;
  static const maxNotesLength = 500;
  static const maxQuantity = 1000000;

  /// Entries created within this window and matching a new entry are flagged
  /// as a likely accidental duplicate (the user may still confirm).
  static const duplicateWindow = Duration(minutes: 5);

  static const fontRegularAsset = 'assets/fonts/Mukta-Regular.ttf';
  static const fontBoldAsset = 'assets/fonts/Mukta-Bold.ttf';

  /// Number of recent transactions shown on the dashboard.
  static const recentCount = 10;
}
