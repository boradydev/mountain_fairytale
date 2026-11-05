import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_card_content.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';

class RoutePointReadOnlyCard extends StatelessWidget {
  final RoutePoint point;
  const RoutePointReadOnlyCard({super.key, required this.point});

  Widget _information(BuildContext context, String label, String value) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
    // Preserve the history pair's outer spacing and available card width.
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: RoutePointCardSurface(
      isDelivered: point.isDelivered,
      child: ExpansionTile(
        key: PageStorageKey('history-point-${point.pointId}'),
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: RoutePointHeader(point: point),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Телефон: ${point.phone}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _information(
                        context,
                        'Форма оплаты',
                        point.documentPaymentMethodName ?? 'Не указана',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _information(
                        context,
                        'Торговый представитель',
                        point.salesRepresentative,
                      ),
                    ),
                  ],
                ),
                if (point.memo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Памятка: ${point.memo}'),
                ],
                if (!point.isDelivered) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Не доставлено: ${point.nonDeliveryReason}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 24),
                const RoutePointTaskHeading(),
                const SizedBox(height: 12),
                RoutePointTaskTable(
                  items: point.items,
                  rowBuilder: (i) => TaskItemRow(
                    index: i,
                    item: point.items[i],
                    enabled: false,
                    allowFreePrice: true,
                    showFullDriverNote: true,
                    strikeThroughAmount: !point.isDelivered,
                    onDelete: () {},
                    onQuantityChanged: (_) {},
                  ),
                  footer: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Итого: ${point.totalAmount.toStringAsFixed(2)} ₽',
                        style: TextStyle(
                          decoration: point.isDelivered
                              ? null
                              : TextDecoration.lineThrough,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
