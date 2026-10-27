import 'package:flutter/material.dart';

/// PlantPal palette: deep soil brown + leaf greens + warm cream,
/// with water blue reserved for watering actions (PLAN.md 7).
class PlantColors {
  static const Color cream = Color(0xFFFFF6E3);
  static const Color soil = Color(0xFF4A3226);
  static const Color soilDark = Color(0xFF2E1F16);
  static const Color leaf = Color(0xFF2E7D32);
  static const Color leafBright = Color(0xFF43A047);
  static const Color leafLight = Color(0xFFA5D6A7);
  static const Color pot = Color(0xFFC1663E);
  static const Color water = Color(0xFF2E86DE);
  static const Color night = Color(0xFF1E2A4A);
  static const Color sun = Color(0xFFFFC93C);
  static const Color danger = Color(0xFFB94A2A);
}

/// Pixel font for headings and pet speech only. Body copy stays in
/// the default readable font — pixel fonts at paragraph size are
/// unreadable (PLAN.md 7).
TextStyle pixelStyle({double size = 16, Color color = PlantColors.soil}) {
  return TextStyle(
    fontFamily: 'PressStart2P',
    fontSize: size,
    color: color,
    height: 1.4,
  );
}

ThemeData plantTheme() {
  return ThemeData(
    scaffoldBackgroundColor: PlantColors.cream,
    colorScheme: const ColorScheme.light(
      primary: PlantColors.leaf,
      secondary: PlantColors.water,
      surface: PlantColors.cream,
      onSurface: PlantColors.soil,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PlantColors.leaf,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: PlantColors.soil),
      bodyLarge: TextStyle(color: PlantColors.soil),
    ),
    useMaterial3: true,
  );
}
