import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_read_only_card.dart';
import 'package:mountain_fairytale/shared/widgets/dialog_card_widget.dart';

class ClientDeliveryCard extends StatelessWidget {
  final ClientDelivery delivery;
  final VoidCallback onOpen;
  const ClientDeliveryCard({
    super.key,
    required this.delivery,
    required this.onOpen,
  });

  Widget _line(BuildContext context, String label, String value) => Tooltip(
    message: value,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final doc = d.document;
    final colors = Theme.of(context).colorScheme;
    final route = AppDialogCard(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(
                  context,
                  'Дата',
                  DateFormat('dd.MM.yyyy').format(doc.plannedDate),
                ),
                _line(context, 'Водитель', doc.driverName ?? 'Не указан'),
                _line(
                  context,
                  'Автомобиль',
                  doc.carModelAndNumber ?? 'Не указан',
                ),
                _line(
                  context,
                  'Сумма',
                  NumberFormat.currency(
                    locale: 'ru_RU',
                    symbol: '₽',
                  ).format(doc.totalAmount),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: colors.onSurfaceVariant),
        ],
      ),
    );
    final point = RoutePointReadOnlyCard(
      point: RoutePoint(
        pointId: d.pointId,
        clientId: d.clientId,
        clientName: d.clientName,
        address: d.address,
        clientAddress: d.clientAddress,
        deliveryDetails: d.deliveryDetails,
        phone: d.phone,
        memo: d.memo,
        isDelivered: d.isDelivered,
        nonDeliveryReason: d.nonDeliveryReason,
        documentPaymentMethodName: d.paymentMethodName,
        salesRepresentativeId: d.salesRepresentativeId,
        salesRepresentative: d.salesRepresentativeName ?? 'Не указан',
        items: d.items
            .map(
              (i) => DeliveryTaskItem(
                itemId: i.itemId,
                productId: i.productId,
                productName: i.productName,
                quantity: i.quantity,
                price: i.price,
                isFreePrice: i.isFreePrice,
                driverNote: i.driverNote,
              ),
            )
            .toList(),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [route, point],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 332, child: route),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: IgnorePointer(
                child: Icon(
                  Icons.link,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: point),
          ],
        );
      },
    );
  }
}
