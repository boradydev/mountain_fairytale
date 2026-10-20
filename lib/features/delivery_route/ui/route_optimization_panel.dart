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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Точек доставки: ${p.points.length}'),
          const SizedBox(height: 4),
          const Text('Склад → доставки → склад'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppSecondaryButton(
                text: 'Оптимизировать порядок',
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
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 4,
            child: p.optimizing
                ? const LinearProgressIndicator(
                    semanticsLabel: 'Расчёт порядка доставок',
                  )
                : null,
          ),
          const SizedBox(height: 8),
          if (p.optimizing)
            const Text(
              'Рассчитываем порядок доставок… Можно закрыть окно: расчёт продолжится.',
            ),
          if (!p.canEdit)
            const Text(
              'Для изменения порядка начните редактирование маршрутного листа.',
            ),
          if (p.points.length < 2)
            const Text('Добавьте не менее двух доставок для расчёта.'),
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
          const SizedBox(height: 12),
          Text(
            'Порядок применяется сразу. Закрытие окна его не отменяет. '
            'Для записи изменений сохраните маршрутный лист.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const GeoAttribution(),
        ],
      ),
    );
  }
}
