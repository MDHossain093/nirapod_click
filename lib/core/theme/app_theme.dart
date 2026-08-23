import 'package:flutter/material.dart';

import '../../models/risk_result.dart';

/// NirapodClick design system — single source of truth.
///
/// Everything visual lives here: brand palette, semantic risk colors,
/// the Material 3 [ThemeData], and the [RiskStyle] helper that maps a
/// [RiskLevel] to (color, icon, badge).
///
/// Screens never hardcode hex values — they read from this class.
class AppTheme {
  AppTheme._();

  // -- Brand colors -------------------------------------------------------
  static const Color primary = Color(0xFF12355B);    // Deep Navy
  static const Color secondary = Color(0xFF0E9F8A);  // Teal
  static const Color accent = Color(0xFFF4B942);     // Amber

  // -- Backgrounds & text -------------------------------------------------
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE5EAF1);

  // -- Semantic risk colors (5-tier) --------------------------------------
  static const Color riskLow = Color(0xFF16A34A);     // green
  static const Color riskMedium = Color(0xFFF59E0B);  // amber
  static const Color riskHigh = Color(0xFFEA580C);    // orange
  static const Color riskCritical = Color(0xFFDC2626);// red
  static const Color danger = riskCritical;          // alias for colorScheme.error
  static const Color success = riskLow;              // alias for "all-clear" UI
  static const Color warning = riskMedium;           // alias for "watch-out" UI

  // -- AI-unavailable banner palette --------------------------------------
  // Soft amber surface used when the local rules verdict was shown because
  // the Gemini fallback path was unavailable. Derived from [riskMedium] so
  // the banner reads as "amber, not red" across the whole app.
  static const Color amberBannerBackground = Color(0xFFFFF4D6);
  static const Color amberBannerBorder = Color(0xFFE8B931);
  static const Color amberBannerIcon = Color(0xFFB07A00);

  // -- Design system tokens ----------------------------------------------
  // Border-radius scale. Screens pick the radius that matches the
  // surface's role; never use an off-scale value.
  static const double radiusXs = 12;   // chips, source badges, URL preview
  static const double radiusSm = 14;   // reason rows, meta cards, inline notice
  static const double radiusMd = 16;   // safety notices, sub-panels
  static const double radiusLg = 18;   // inline cards, list tiles
  static const double radiusXl = 20;   // result cards, premium surfaces
  static const double radiusXxl = 22;  // primary result header (URL/Phone)
  static const double radiusHero = 24; // marketing hero cards

  // Square tile sizes. Use to keep row + header icons consistent.
  static const double tileIconSm = 44; // history rows
  static const double tileIconMd = 52; // learn / check list rows
  static const double tileIconLg = 64; // empty-state placeholders
  static const double tileIconXl = 72; // result-header icon circle

  // Tint alpha scale. Use to keep "level-tinted" surfaces consistent.
  static const double tintSurface = 0.10; // colored card surface fill
  static const double tintBorder = 0.25; // colored card border
  static const double tintSubtle = 0.08; // primary-tinted row icon
  static const double tintPanel = 0.06;  // primary-tinted reminder card

  // -- Hero gradient ------------------------------------------------------
  static const LinearGradient brandHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primary,
      Color(0xFF1B4D7A),
      secondary,
    ],
  );

  // -- Material 3 light theme --------------------------------------------
  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: accent,
      onTertiary: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
      onError: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,

      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: secondary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
          ),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Visual style for a [RiskLevel].
///
/// The same scam verdict looks identical in Result + History pages
/// because both go through [RiskStyle.of].
class RiskStyle {
  final Color color;
  final Color onColor;
  final IconData icon;
  final String badge;

  const RiskStyle({
    required this.color,
    required this.onColor,
    required this.icon,
    required this.badge,
  });

  static RiskStyle of(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return const RiskStyle(
          color: AppTheme.riskLow,
          onColor: Colors.white,
          icon: Icons.verified_outlined,
          badge: 'SAFE',
        );
      case RiskLevel.low:
        return const RiskStyle(
          color: AppTheme.riskLow,
          onColor: Colors.white,
          icon: Icons.verified_outlined,
          badge: 'LOW',
        );
      case RiskLevel.medium:
        return const RiskStyle(
          color: AppTheme.riskMedium,
          onColor: AppTheme.textPrimary,
          icon: Icons.warning_amber_outlined,
          badge: 'MEDIUM',
        );
      case RiskLevel.high:
        return const RiskStyle(
          color: AppTheme.riskHigh,
          onColor: Colors.white,
          icon: Icons.dangerous_outlined,
          badge: 'HIGH',
        );
      case RiskLevel.critical:
        return const RiskStyle(
          color: AppTheme.riskCritical,
          onColor: Colors.white,
          icon: Icons.report_gmailerrorred_outlined,
          badge: 'CRITICAL',
        );
    }
  }
}