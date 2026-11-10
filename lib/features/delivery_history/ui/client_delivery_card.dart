import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_read_only_card.dart';
import 'package:mountain_fairytale/shared/widgets/document_summary_card.dart';

class ClientDeliveryCard extends StatelessWidget {
  final ClientDelivery delivery;
  final VoidCallback onOpen;
  const ClientDeliveryCard({
    super.key,
    required this.delivery,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final doc = d.document;
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final route = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: DocumentSummaryCard(
        isPickup: doc.isPickup,
        date: DateFormat.yMd(locale).format(doc.plannedDate),
        driver: doc.driverName ?? 'Не указан',
        car: doc.carModelAndNumber ?? 'Не указан',
        isActive: doc.isActive,
        onOpen: onOpen,
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
            SizedBox(
              width: ((constraints.maxWidth - 18) / 2).clamp(0, 400),
              child: route,
            ),
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
