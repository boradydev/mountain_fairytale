import 'package:flutter/material.dart';

/// Конфигуратор глобальной темы оформления приложения.
///
/// Класс предоставляет статические методы для генерации светлой и темной тем
/// на основе единой цветовой палитры (seed color).
class AppTheme {
  static ThemeData createTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
    );
  }
}
