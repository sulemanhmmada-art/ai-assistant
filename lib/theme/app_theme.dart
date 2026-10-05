import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundColor = Color(0xFF030712); // أسود داكن جداً OLED
  static const Color surfaceColor = Color(0x1AFFFFFF); // زجاجي شفاف
  static const Color accentGlow = Color(0xFF00F0FF); // أزرق نيون
  static const Color secondaryGlow = Color(0xFF7000FF); // بنفسجي نيون
  
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: accentGlow,
        secondary: secondaryGlow,
        surface: surfaceColor,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }
}
