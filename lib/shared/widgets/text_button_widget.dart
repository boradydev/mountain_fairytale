import 'package:flutter/material.dart';

/// Полноцветная кнопка для основного/предпочтительного действия.
class AppPrimaryButton extends StatelessWidget {
  final String text;
  final int? maxLines;
  final VoidCallback? onPressed;
  final bool destructive;

  const AppPrimaryButton({
    super.key,
    required this.text,
    this.maxLines,
    this.onPressed,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = destructive
        ? colorScheme.error
        : colorScheme.primary;

    final foregroundColor = destructive
        ? colorScheme.onError
        : colorScheme.onPrimary;

    return FilledButton(
      onPressed: onPressed,
      style:
          FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: 16,
            ),
            shape: const StadiumBorder(),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.pressed)) {
                return foregroundColor.withAlpha(40);
              }

              if (states.contains(WidgetState.hovered)) {
                return Colors.black.withAlpha(25);
              }

              return null;
            }),
          ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
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
  final int? maxLines;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AppSecondaryButton({
    super.key,
    required this.text,
    this.maxLines,
    this.onPressed,
    this.icon,
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
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: 16,
        ),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
