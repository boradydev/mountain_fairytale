import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';

class ActiveStatusLabel extends StatelessWidget {
  final bool isActive;

  const ActiveStatusLabel({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final success = theme.extension<AppColorsExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isActive
        ? success?.successColor ??
              (isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20))
        : colors.onSurfaceVariant;

    return Text(
      isActive ? 'Активен' : 'Деактивирован',
      style: theme.textTheme.labelMedium?.copyWith(color: foreground),
    );
  }
}
