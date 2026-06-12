import 'package:flutter/material.dart';

const Color backgroundCream = Color(0xFFFAF7F2);
const Color surfaceWhite = Color(0xFFFFFFFF);
const Color primaryTerracotta = Color(0xFFC8603A);
const Color accentSage = Color(0xFF6A9E88);
const Color textPrimary = Color(0xFF2C2A26);
const Color textMuted = Color(0xFF7A7568);
const Color warmBeige = Color(0xFFEDE8E0);
const Color sand = Color(0xFFC8943A);
const Color dustySky = Color(0xFF8BB4C8);
const Color mauve = Color(0xFFB08EA0);
const Color couplePink = Color(0xFFC87888);

// rgba(44,42,38,0.08) ≈ 0x14
const Color borderWarm = Color(0x142C2A26);
// rgba(44,42,38,0.15) ≈ 0x26
const Color borderWarmStrong = Color(0x262C2A26);

Color categoryChipBg(String category) {
  switch (category) {
    case 'Creative':
      return const Color(0xFFFAF0EC);
    case 'Outside':
      return const Color(0xFFEEF6F2);
    case 'Couple time':
      return const Color(0xFFFAF0F2);
    case 'Social':
      return const Color(0xFFF6EEF3);
    case 'At home':
      return const Color(0xFFFDF5EC);
    case 'Rest':
      return const Color(0xFFF2F0F8);
    default:
      return const Color(0xFFF4F2EE);
  }
}

Color categoryChipText(String category) {
  switch (category) {
    case 'Creative':
      return primaryTerracotta;
    case 'Outside':
      return accentSage;
    case 'Couple time':
      return couplePink;
    case 'Social':
      return mauve;
    case 'At home':
      return sand;
    case 'Rest':
      return const Color(0xFF9A90BE);
    default:
      return const Color(0xFF9E9888);
  }
}

Color categoryIconColor(String category) => categoryChipText(category);
