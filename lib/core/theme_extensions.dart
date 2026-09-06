import 'package:flutter/material.dart';

/// Расширение темы для добавления кастомных цветов,
/// которых нет в стандартном ColorScheme (например, цвета предупреждений).
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color warningColor;
  final Color warningContainer;

  const AppColorsExtension({
    required this.warningColor,
    required this.warningContainer,
  });

  @override
  AppColorsExtension copyWith({Color? warningColor, Color? warningContainer}) {
    return AppColorsExtension(
      warningColor: warningColor ?? this.warningColor,
      warningContainer: warningContainer ?? this.warningContainer,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
    );
  }
}
