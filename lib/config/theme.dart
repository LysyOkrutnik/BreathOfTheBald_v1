import 'package:flutter/material.dart';

class AppTheme {
  // --- PALETTE ---

  static const Color background = Color(0xFF101820);

  // Use true black for session backgrounds to minimize screen glare.
  static const Color sessionBackground = Colors.black;

  static const Color primary = Color(0xFF81C784);
  static const Color accent = Color(0xFF4DD0E1);
  static const Color danger = Color(0xFFE57373);

  // Use off-white to reduce eye strain in dark mode.
  static const Color textLight = Color(0xFFF5F5F5);
  static const Color textDim = Color(0xFFB0BEC5);

  // Define colors for the breathing animation blob.
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
    // Prevent horizontal jitter during timer countdown.
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    fontFamily: 'Roboto',
    useMaterial3: true,
  );
}