import 'package:flutter/material.dart';

class MetricRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final double? labelWidth;
  final Color? iconColor;
  final Color? valueColor;

  const MetricRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.labelWidth,
    this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Если иконка передана, показываем её и отступ
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: iconColor ?? colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
          ],
          // SizedBox с width: null не ограничивает ширину и подстраивается под текст
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
