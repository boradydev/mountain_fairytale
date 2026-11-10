import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/features/clients/data/client_latest_order.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_card_content.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class ClientLatestOrderDialog extends StatefulWidget {
  final DateTime plannedDate;
  final Future<ClientLatestOrder?> Function() loadOrder;
  const ClientLatestOrderDialog({
    super.key,
    required this.plannedDate,
    required this.loadOrder,
  });

  @override
  State<ClientLatestOrderDialog> createState() =>
      _ClientLatestOrderDialogState();
}

class _ClientLatestOrderDialogState extends State<ClientLatestOrderDialog> {
  late Future<ClientLatestOrder?> _order;

  @override
  void initState() {
    super.initState();
    _order = Future.sync(widget.loadOrder);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ClientLatestOrder?>(
    future: _order,
    builder: (context, snapshot) {
      // Never render a previous response while a retry is in progress.
      final loading = snapshot.connectionState != ConnectionState.done;
      final order = loading ? null : snapshot.data;
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          'Последний заказ — ${(order?.plannedDate ?? widget.plannedDate).toFormattedString()}',
        ),
        content: SizedBox(
          width: 960,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .65,
            ),
            child: SingleChildScrollView(
              child: loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Не удалось загрузить последний заказ. Повторите попытку.',
                        ),
                        const SizedBox(height: 12),
                        AppSecondaryButton(
                          text: 'Повторить',
                          onPressed: () {
                            setState(() {
                              _order = Future.sync(widget.loadOrder);
                            });
                          },
                        ),
                      ],
                    )
                  : order == null
                  ? const Text('Подходящего заказа больше нет.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RoutePointTaskHeading(),
                        const SizedBox(height: 12),
                        RoutePointTaskTable(
                          items: order.items,
                          rowBuilder: (i) => TaskItemRow(
                            index: i,
                            item: order.items[i],
                            enabled: false,
                            allowFreePrice: true,
                            showFullDriverNote: true,
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
                                'Итого: ${order.totalAmount.toStringAsFixed(2)} ₽',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        actions: [
          AppSecondaryButton(
            text: 'Закрыть',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    },
  );
}
