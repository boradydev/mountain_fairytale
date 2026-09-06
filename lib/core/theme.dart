import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';

/// Конфигуратор глобальной темы оформления приложения.
///
/// Класс предоставляет статические методы для генерации светлой и темной тем
/// на основе единой цветовой палитры (seed color).
class AppTheme {
  static ThemeData createTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),

      // Регистрируем кастомные цвета внутри темы
      extensions: [
        AppColorsExtension(
          // --- WARNING COLORS ---
          // Для светлой темы используем ваш четкий оранжевый, для темной — чуть светлее и пастельнее
          warningColor: isDark
              ? const Color(0xFFFF9800)
              : const Color(0xFFED6C02),
          // Мягкий фон для плашки
          warningContainer: isDark
              ? const Color(0xFF3E2723)
              : const Color(0xFFFFF3E0),

          // --- GOOD COLORS ---
          // Насыщенный зеленый для текста/иконок успеха
          successColor: isDark
              ? const Color(0xFF81C784)
              : const Color(0xFF2E7D32),
          // Мягкий зеленый фон для плашки
          successContainer: isDark
              ? const Color(0xFF1B5E20).withAlpha(
              40) // Ненасыщенный темно-зеленый
              : const Color(0xFFE8F5E9), // Приятный светло-зеленый
        ),
      ],
    );
  }
}
