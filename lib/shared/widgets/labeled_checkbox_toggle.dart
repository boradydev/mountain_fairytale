import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact, rounded checkbox control whose whole label area is tappable.
class LabeledCheckboxToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? tooltip;

  const LabeledCheckboxToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final scale = math.max(1.0, textScaler.scale(14) / 14);
    final controlHeight = math.max(48.0, textScaler.scale(14) * 1.4 + 24);
    final enabled = onChanged != null;
    final disabledColor = colors.onSurface.withValues(alpha: 0.38);
    final iconColor = !enabled
        ? disabledColor
        : value
        ? colors.primary
        : colors.onSurfaceVariant;

    Widget control = Semantics(
      toggled: value,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular((controlHeight - 8 * scale) / 2),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 8 * scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                color: iconColor,
                size: 20 * scale,
              ),
              SizedBox(width: 8 * scale),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: enabled ? null : disabledColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      control = Tooltip(message: tooltip!, child: control);
    }

    return control;
  }
}
