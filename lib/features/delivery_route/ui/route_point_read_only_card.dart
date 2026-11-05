import 'package:mountain_fairytale/features/delivery_route/ui/route_point_labels.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';

class RoutePointReadOnlyCard extends StatelessWidget {
  final RoutePoint point;
  const RoutePointReadOnlyCard({super.key, required this.point});

  Widget _line(String value) => Tooltip(
    message: value,
    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) => AppBaseCard(
    child: ExpansionTile(
      key: PageStorageKey('history-point-${point.pointId}'),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(point.clientName),
          _line(point.address),
          if (point.memo.isNotEmpty) _line('Памятка: ${point.memo}'),
          if (!point.isDelivered)
            _line('Не доставлено: ${point.nonDeliveryReason}'),
          Text(
            '${point.totalAmount.toStringAsFixed(2)} ₽',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: point.isDelivered ? null : TextDecoration.lineThrough,
            ),
          ),
          _line(
            '${point.items.length} ${routePointPositionsLabel(point.items.length)} · ${point.documentPaymentMethodName ?? 'Оплата не указана'}',
          ),
        ],
      ),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Задание для водителя'),
        ),
        for (var i = 0; i < point.items.length; i++)
          TaskItemRow(
            index: i,
            item: point.items[i],
            enabled: false,
            allowFreePrice: true,
            onDelete: () {},
            onQuantityChanged: (_) {},
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (point.memo.isNotEmpty) Text('Памятка: ${point.memo}'),
              if (!point.isDelivered)
                Text('Не доставлено: ${point.nonDeliveryReason}'),
              Text('Телефон: ${point.phone}'),
              Text(
                'Способ оплаты: ${point.documentPaymentMethodName ?? 'Не указан'}',
              ),
              Text('Представитель: ${point.salesRepresentative}'),
            ],
          ),
        ),
      ],
    ),
  );
}
