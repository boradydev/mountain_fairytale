import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';

/// Конфигуратор глобальной темы оформления приложения.
class AppTheme {
  static ThemeData createTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Используем глубокий синий/голубой цвет как основу для водной тематики
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0077B6), // Чистый океанский / горный синий
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),

      extensions: [
        AppColorsExtension(
          // --- WARNING COLORS ---
          warningColor: isDark
              ? const Color(0xFFFFB74D) // Мягкий янтарный
              : const Color(0xFFE65100), // Глубокий оранжевый
          warningContainer: isDark
              ? const Color(0xFF2C1D11) // Темно-коричневый оттенок
              : const Color(0xFFFFF3E0), // Светло-оранжевый
          // --- GOOD COLORS ---
          successColor: isDark
              ? const Color(0xFF81C784) // Пастельный зеленый
              : const Color(0xFF1B5E20), // Темно-зеленый успех
          successContainer: isDark
              ? const Color(0xFF0C2411) // Очень темный зеленый фон
              : const Color(0xFFE8F5E9), // Приятный светло-зеленый
        ),
      ],
    );
  }
}
