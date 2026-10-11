import 'package:flutter/material.dart';

/// Универсальный базовый виджет карточки для всего приложения.
/// Отвечает исключительно за границы, тени, скругления, фоны и реакцию на нажатия.
class AppBaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AppBaseCard({super.key, required this.child, this.onTap});

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
      // Защищает InkWell от вылезания за углы
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
