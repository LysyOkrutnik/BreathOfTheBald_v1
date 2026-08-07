import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- PALETTE ---

  static const Color background = Color(0xFF101820);

  // Use true black for session backgrounds to maximize immersion and minimize screen glare.
  static const Color sessionBackground = Colors.black;

  static const Color primary = Color(0xFF81C784);
  static const Color accent = Color(0xFF4DD0E1);
  static const Color danger = Color(0xFFE57373);

  // Use an off-white color to reduce eye strain in dark mode.
  static const Color textLight = Color(0xFFF5F5F5);
  static const Color textDim = Color(0xFFB0BEC5);

  // Define colors for the breathing animation.
  static const Color breathInhale = Color(0xFF29B6F6);
  static const Color breathExhale = Colors.white;

  // --- STYLES ---

  static final TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textLight,
    letterSpacing: 1.5,
  );

  static final TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    color: textLight,
    letterSpacing: 0.5,
  );

  static final TextStyle timerStyle = TextStyle(
    fontSize: 70,
    fontWeight: FontWeight.w100,
    color: textLight,
    // Use tabular figures to prevent horizontal jitter during timer updates.
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Used for skeleton/shimmer placeholders.
  static const Color shimmerBase = Color(0xFF1E2730);
  static const Color shimmerHighlight = Color(0xFF2C3845);

  // --- THEME ---

  static const ColorScheme _colorScheme = ColorScheme.dark(
    primary: primary,
    onPrimary: Colors.black,
    secondary: accent,
    onSecondary: Colors.black,
    error: danger,
    onError: Colors.black,
    surface: background,
    onSurface: textLight,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    fontFamily: GoogleFonts.montserrat().fontFamily,
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: textLight, displayColor: textLight),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: textLight,
      centerTitle: true,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    dialogTheme: const DialogThemeData(backgroundColor: background),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: primary,
      contentTextStyle: TextStyle(color: Colors.black),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? primary.withAlpha(120) : null,
      ),
    ),
  );

  // --- DEPTH & SURFACES ---

  /// The app's base vertical gradient. A deep, warm near-black with a whisper
  /// of forest green at the top — reads as a considered wellness-studio
  /// backdrop rather than a flat technical gray.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF141F1B), Color(0xFF05070A)],
  );

  /// A soft frosted-glass surface decoration used for cards and dialogs.
  static BoxDecoration glass({
    double radius = AppRadius.lg,
    Color? tint,
    double borderOpacity = 0.16,
  }) {
    return BoxDecoration(
      color: (tint ?? Colors.white).withAlpha(24),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withAlpha((borderOpacity * 255).round())),
    );
  }

  /// An ambient outer glow, e.g. for an accent button or active element.
  static List<BoxShadow> glow(Color color, {double blur = 20, double spread = 0}) {
    return [
      BoxShadow(
        color: color.withAlpha(90),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];
  }

  /// A left-to-right tinted gradient for level/stat cards — a confident wash
  /// of colour rather than a faint hint.
  static LinearGradient cardGradient(Color color) => LinearGradient(
        colors: [color.withAlpha(56), color.withAlpha(10)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
}

/// 4-pt based spacing scale.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radius scale. Softer/rounder than the original for a calmer,
/// more premium feel.
abstract final class AppRadius {
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double pill = 999;
}

/// Shared motion durations for a consistent feel.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 700);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}