import 'package:flutter/material.dart';

class DeliveryDayCard extends StatelessWidget {
  final String title;
  final List<Widget> metrics;
  final VoidCallback? onTap;

  const DeliveryDayCard({
    super.key,
    required this.title,
    required this.metrics,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(128),
          width: 1,
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      // Чтобы InkWell не вылезал за скругления
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: colorScheme.outlineVariant, height: 1),
              const SizedBox(height: 8),
              ...metrics,
            ],
          ),
        ),
      ),
    );
  }
}
