import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';

import 'package:mountain_fairytale/features/delivery_route/ui/route_point_labels.dart';

/// Pure presentation shared by route documents and historical snapshots.
class RoutePointCardSurface extends StatelessWidget {
  final bool isDelivered;
  final Widget child;
  const RoutePointCardSurface({
    super.key,
    required this.isDelivered,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDelivered
            ? colorScheme.surfaceContainerLow
            : (Theme.of(context)
                      .extension<AppColorsExtension>()
                      ?.warningContainer ??
                  Color.alphaBlend(
                    colorScheme.error.withValues(alpha: 0.08),
                    colorScheme.surfaceContainerLow,
                  )),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}

class RoutePointHeader extends StatelessWidget {
  final RoutePoint point;
  final bool isPickup;
  final String pickupTitle;
  const RoutePointHeader({
    super.key,
    required this.point,
    this.isPickup = false,
    this.pickupTitle = '',
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPickup ? pickupTitle : point.clientName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isPickup && point.memo.isNotEmpty)
              Tooltip(
                message: 'Памятка: ${point.memo}',
                child: Text.rich(
                  TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      const TextSpan(
                        text: 'Памятка: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: point.memo),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (!point.isDelivered)
              Tooltip(
                message: 'Не доставлено: ${point.nonDeliveryReason}',
                child: Text(
                  'Не доставлено: ${point.nonDeliveryReason}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!isPickup) const SizedBox(height: 4),
            if (!isPickup)
              Text(
                point.address,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        );
        final summary = Column(
          crossAxisAlignment: constraints.maxWidth < 440
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Text(
              point.items.isEmpty
                  ? 'Задание не заполнено'
                  : '${point.totalAmount.toStringAsFixed(2)} ₽',
              style: TextStyle(
                decoration: point.isDelivered
                    ? null
                    : TextDecoration.lineThrough,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: point.items.isEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${point.items.length} ${routePointPositionsLabel(point.items.length)} · ${point.documentPaymentMethodName ?? 'Оплата не указана'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 8),
              summary,
            ],
          );
        }
        return Row(
          crossAxisAlignment: isPickup
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            const SizedBox(width: 20),
            Expanded(child: summary),
          ],
        );
      },
    );
  }
}

class RoutePointTaskHeading extends StatelessWidget {
  final bool isPickup;
  const RoutePointTaskHeading({super.key, this.isPickup = false});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.assignment_outlined,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isPickup ? 'Товары и услуги' : 'Задание для водителя',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class RoutePointTaskTable extends StatelessWidget {
  final List<DeliveryTaskItem> items;
  final Widget Function(int) rowBuilder;
  final Widget footer;
  const RoutePointTaskTable({
    super.key,
    required this.items,
    required this.rowBuilder,
    required this.footer,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          if (items.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 700
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.labelMedium!,
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Продукция / услуга',
                              ),
                            ),
                            SizedBox(
                              width: 156,
                              child: Text(
                                'Количество',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 112,
                              child: Text(
                                'Цена',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 112,
                              child: Text(
                                'Сумма',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Продукция или услуги не добавлены',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          for (var i = 0; i < items.length; i++) ...[
            rowBuilder(i),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant,
              ),
          ],
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          footer,
        ],
      ),
    );
  }
}
