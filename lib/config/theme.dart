import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  

  static const Color background = Color(0xFF101820);

  
  static const Color sessionBackground = Colors.black;

  static const Color primary = Color(0xFF81C784);
  static const Color accent = Color(0xFF4DD0E1);
  static const Color danger = Color(0xFFE57373);

  
  static const Color textLight = Color(0xFFF5F5F5);
  static const Color textDim = Color(0xFFB0BEC5);

  
  static const Color breathInhale = Color(0xFF29B6F6);
  static const Color breathExhale = Colors.white;

  

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
    
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    fontFamily: GoogleFonts.montserrat().fontFamily,
    useMaterial3: true,
  );
}