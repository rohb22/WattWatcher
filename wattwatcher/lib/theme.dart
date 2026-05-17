import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core palette
  static const Color bg = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFF151C2E);
  static const Color surfaceHigh = Color(0xFF1A2338);
  static const Color border = Color(0xFF1E2A40);
  static const Color borderHigh = Color(0xFF2A3A56);

  static const Color accent = Color(0xFF4FC3F7);
  static const Color accentDim = Color(0xFF1A3A5C);
  static const Color green = Color(0xFF4CAF7D);
  static const Color greenDim = Color(0xFF0D3320);
  static const Color amber = Color(0xFFFFC107);
  static const Color amberDim = Color(0xFF2A1E05);
  static const Color red = Color(0xFFF48FB1);
  static const Color redDim = Color(0xFF2A0D0D);
  static const Color redBorder = Color(0xFF6A1A1A);

  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF90CAF9);
  static const Color textMuted = Color(0xFF000000);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: green,
          surface: surface,
          error: red,
        ),
        textTheme: GoogleFonts.interTextTheme(
          const TextTheme(
            displayLarge: TextStyle(color: textPrimary),
            bodyLarge: TextStyle(color: textPrimary),
            bodyMedium: TextStyle(color: textSecondary),
            bodySmall: TextStyle(color: textMuted),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: const IconThemeData(color: textSecondary),
        ),
        dividerColor: border,
        cardColor: surface,
      );
}
