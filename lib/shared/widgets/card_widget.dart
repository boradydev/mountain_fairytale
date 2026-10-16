import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';

class DeliveryDayCard extends StatelessWidget {
  final String title;
  final List<Widget> metrics;
  final VoidCallback? onTap;
  final Widget? titleSuffix;
  final Color? backgroundColor;
  final InlineSpan? titleSpan;

  const DeliveryDayCard({
    super.key,
    required this.title,
    required this.metrics,
    this.onTap,
    this.titleSuffix,
    this.backgroundColor,
    this.titleSpan,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBaseCard(
      onTap: onTap,
      backgroundColor: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  titleSpan ?? TextSpan(text: title),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (titleSuffix != null) ...[
                const SizedBox(width: 8),
                titleSuffix!,
              ],
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 8),
          ...metrics,
        ],
      ),
    );
  }
}
