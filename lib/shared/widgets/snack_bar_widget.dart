import 'package:flutter/material.dart';

/// Shared notification styling, independent of a Scaffold or Navigator route.
class AppSnackBarContent extends StatelessWidget {
  final String message;
  final bool isError;
  final bool isWarning;

  const AppSnackBarContent({
    super.key,
    required this.message,
    this.isError = false,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Color.alphaBlend(
      colorScheme.onSurface.withAlpha(isDark ? 20 : 12),
      colorScheme.surfaceContainerHighest,
    );
    final (statusIcon, iconColor) = switch ((isError, isWarning)) {
      (true, _) => (Icons.error_outline_rounded, colorScheme.error),
      (_, true) => (Icons.warning_amber_rounded, const Color(0xFFED6C02)),
      _ => (Icons.check_circle_outline_rounded, colorScheme.primary),
    };

    return Material(
      type: MaterialType.transparency,
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withAlpha(isDark ? 204 : 166),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 110 : 50),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: iconColor, size: 24),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
