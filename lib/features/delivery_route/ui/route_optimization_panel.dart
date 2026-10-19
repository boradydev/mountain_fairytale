import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/geo_attribution.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class RouteOptimizationPanel extends StatelessWidget {
  final RouteConstructorProvider provider;
  const RouteOptimizationPanel({super.key, required this.provider});
  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppSecondaryButton(
                text: p.optimizing
                    ? 'Расчёт порядка…'
                    : 'Оптимизировать порядок',
                onPressed:
                    p.canEdit &&
                        !p.optimizing &&
                        p.points.length >= 2 &&
                        p.points.length <= 30 &&
                        p.locationRepository != null
                    ? p.optimizeOrder
                    : null,
              ),
              AppSecondaryButton(
                text: 'Отменить перестановку',
                onPressed: p.canUndoOptimization ? p.undoOptimization : null,
              ),
              const Text('Склад → доставки → склад'),
            ],
          ),
          if (p.points.length > 30)
            const Text('Для расчёта допускается не более 30 доставок.'),
          if (p.optimizationMessage != null)
            Text(
              p.optimizationMessage!,
              style: TextStyle(
                color: p.optimizationFailed
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          const GeoAttribution(),
        ],
      ),
    );
  }
}
