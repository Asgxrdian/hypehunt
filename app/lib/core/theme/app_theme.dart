import 'package:flutter/material.dart';

/// HyperHunt design tokens — the ONLY place colors and type live.
/// Constitution: dark UI, lime green primary, cyan secondary,
/// premium, minimal, no visual clutter.
abstract final class HyperColors {
  static const background = Color(0xFF0B0E11); // near-black
  static const surface = Color(0xFF14181D);
  static const surfaceRaised = Color(0xFF1B2129);
  static const lime = Color(0xFFB6F542); // primary accent — actions, highlights
  static const cyan = Color(0xFF3EE0F0); // secondary — informational only
  static const textPrimary = Color(0xFFF2F5F7);
  static const textSecondary = Color(0xFF9AA5B1);
  static const danger = Color(0xFFFF5C5C);
}

ThemeData buildHyperTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: HyperColors.lime,
      secondary: HyperColors.cyan,
      surface: HyperColors.surface,
      error: HyperColors.danger,
      onPrimary: HyperColors.background,
      onSurface: HyperColors.textPrimary,
    ),
    scaffoldBackgroundColor: HyperColors.background,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: HyperColors.background,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: HyperColors.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HyperColors.surface,
      indicatorColor: HyperColors.lime.withValues(alpha: 0.16),
    ),
  );
}
