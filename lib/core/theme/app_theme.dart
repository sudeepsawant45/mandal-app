import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

/// Visual identity: royal blue + white, pale-blue surfaces, rounded cards, and
/// gold used only as a small accent. Every screen takes its look from this
/// theme so the app stays consistent.
class AppTheme {
  AppTheme._();

  static const royalBlue = Color(0xFF0D47A1);
  static const blue = Color(0xFF1565C0);
  static const paleBlue = Color(0xFFE8F0FB);
  static const background = Color(0xFFF4F7FC);
  static const gold = Color(0xFFF9A825);
  static const saffron = Color(0xFFEF6C00);
  static const textDark = Color(0xFF1B2733);

  static const seed = royalBlue;

  static const double radius = 16;
  static const double fieldRadius = 12;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: royalBlue,
      primary: royalBlue,
      secondary: gold,
      surface: Colors.white,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xB3FFFFFF),
        indicatorColor: gold,
        dividerColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: const Color(0x26000000),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: const BorderSide(color: royalBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(fieldRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: royalBlue,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: royalBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(fieldRadius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: royalBlue, minimumSize: const Size(48, 44)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: paleBlue,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? royalBlue : const Color(0xFF5B6B7B),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? royalBlue : const Color(0xFF5B6B7B),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: paleBlue,
          selectedForegroundColor: royalBlue,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1, color: Color(0xFFE3E9F2)),
    );
  }
}

/// One accent colour per fund so the four ledgers are never visually confused.
/// All four are chosen to sit well on the blue-and-white theme.
class FundColors {
  FundColors._();

  static Color of(Fund fund) {
    switch (fund) {
      case Fund.householdDonation:
        return const Color(0xFFEF6C00); // saffron
      case Fund.commonMandal:
        return const Color(0xFF1565C0); // blue
      case Fund.visarjan:
        return const Color(0xFF00897B); // teal
      case Fund.tshirtSponsorship:
        return const Color(0xFF7B1FA2); // purple
    }
  }

  static IconData iconOf(Fund fund) {
    switch (fund) {
      case Fund.householdDonation:
        return Icons.home_work_outlined;
      case Fund.commonMandal:
        return Icons.account_balance_wallet_outlined;
      case Fund.visarjan:
        return Icons.water_drop_outlined;
      case Fund.tshirtSponsorship:
        return Icons.checkroom_outlined;
    }
  }

  /// Green for money in, red for money out, blue for balances.
  static const income = Color(0xFF2E7D32);
  static const expense = Color(0xFFC62828);
  static const balance = Color(0xFF1565C0);
}
