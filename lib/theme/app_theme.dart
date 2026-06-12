import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: primaryTerracotta,
      secondary: accentSage,
      surface: surfaceWhite,
    ),
    scaffoldBackgroundColor: backgroundCream,
    cardColor: surfaceWhite,
    useMaterial3: true,
  );

  return base.copyWith(
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.lora(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.2,
      ),
    ),
  );
}
