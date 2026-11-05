import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_read_only_card.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';

class ClientDeliveryCard extends StatelessWidget {
  final ClientDelivery delivery;
  final VoidCallback onOpen;
  const ClientDeliveryCard({
    super.key,
    required this.delivery,
    required this.onOpen,
  });

  Widget _line(String value) => Tooltip(
    message: value,
    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final doc = d.document;
    final route = AppBaseCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('dd.MM.yyyy').format(doc.plannedDate)),
          _line(doc.driverName ?? 'Водитель не указан'),
          _line(doc.carModelAndNumber ?? 'Машина не указана'),
          _line('Маршрут: ${doc.totalAmount.toStringAsFixed(2)} ₽'),
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
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [route, point],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 240, child: route),
            Expanded(child: point),
          ],
        );
      },
    );
  }
}
