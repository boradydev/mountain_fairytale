import 'package:flutter/material.dart';

SnackBar buildCustomSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isWarning = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  final Color backgroundColor = colorScheme.surfaceContainerHigh;
  final Color textColor = colorScheme.onSurface;

  IconData? statusIcon;
  Color iconColor;

  if (isError) {
    statusIcon = Icons.error_outline_rounded;
    iconColor = colorScheme.error;
  } else if (isWarning) {
    statusIcon = Icons.warning_amber_rounded;
    iconColor = const Color(0xFFED6C02);
  } else {
    statusIcon = Icons.check_circle_outline_rounded;
    iconColor = colorScheme.primary;
  }

  return SnackBar(
    width: 390,
    behavior: SnackBarBehavior.floating,
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    elevation: 4,
    duration: const Duration(seconds: 3),
    content: Row(
      children: [
        Icon(statusIcon, color: iconColor, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            message,
            textAlign: TextAlign.start,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}
