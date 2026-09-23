import 'package:flutter/material.dart';

SnackBar buildAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isWarning = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  final backgroundColor = colorScheme.surfaceContainerHigh;
  final textColor = colorScheme.onSurface;

  final (statusIcon, iconColor) = switch ((isError, isWarning)) {
    (true, _) => (
      Icons.error_outline_rounded,
      colorScheme.error,
    ),
    (_, true) => (
      Icons.warning_amber_rounded,
      const Color(0xFFED6C02),
    ),
    _ => (
      Icons.check_circle_outline_rounded,
      colorScheme.primary,
    ),
  };

  return SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    content: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  color: iconColor,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
