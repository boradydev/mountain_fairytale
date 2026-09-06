import 'package:flutter/material.dart';


/// Полноцветная кнопка для основного/предпочтительного действия.
class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const AppPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ).copyWith(
        // Настраиваем поведение цвета при наведении и нажатии
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            // При нажатии кнопка станет еще темнее
            return colorScheme.onPrimary.withAlpha(40);
          }
          if (states.contains(WidgetState.hovered)) {
            // При наведении мыши накладываем полупрозрачный черный слой (затемняем primary-цвет)
            return Colors.black.withAlpha(25);
          }
          return null; // Стандартное состояние
        }),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


/// Кнопка в окантовке (Outlined) для второстепенного/альтернативного действия (например, "Отмена", "Назад").
class AppSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const AppSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        // Сделаем текст чуть спокойнее, чтобы не спорил с основной кнопкой
        // Изменили outlineVariant на outline и увеличили толщину до 1.5 для десктопной четкости
        side: BorderSide(color: colorScheme.outline, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
