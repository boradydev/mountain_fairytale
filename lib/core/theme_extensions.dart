import 'package:flutter/material.dart';

/// Расширение темы для добавления кастомных цветов,
/// которых нет в стандартном ColorScheme (например, цвета предупреждений и успеха).
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color warningColor;
  final Color warningContainer;
  final Color successColor;
  final Color successContainer;

  const AppColorsExtension({
    required this.warningColor,
    required this.warningContainer,
    required this.successColor,
    required this.successContainer,
  });

  @override
  AppColorsExtension copyWith({
    Color? warningColor,
    Color? warningContainer,
    Color? successColor,
    Color? successContainer,
  }) {
    return AppColorsExtension(
      warningColor: warningColor ?? this.warningColor,
      warningContainer: warningContainer ?? this.warningContainer,
      successColor: successColor ?? this.successColor,
      successContainer: successContainer ?? this.successContainer,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      warningContainer: Color.lerp(
          warningContainer, other.warningContainer, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      successContainer: Color.lerp(
          successContainer, other.successContainer, t)!,
    );
  }
}
