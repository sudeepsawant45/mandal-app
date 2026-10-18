import 'package:flutter/material.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

class AppTheme {
  AppTheme._();

  static const seed = Color(0xFFE65100); // saffron

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// One accent colour per fund so the four ledgers are never visually confused.
class FundColors {
  FundColors._();

  static Color of(Fund fund) {
    switch (fund) {
      case Fund.householdDonation:
        return const Color(0xFFE65100); // deep orange
      case Fund.commonMandal:
        return const Color(0xFF3949AB); // indigo
      case Fund.visarjan:
        return const Color(0xFF00897B); // teal
      case Fund.tshirtSponsorship:
        return const Color(0xFF8E24AA); // purple
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

  static const income = Color(0xFF2E7D32);
  static const expense = Color(0xFFC62828);
}
