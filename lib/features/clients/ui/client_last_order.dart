import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/data/client_latest_order.dart';
import 'package:mountain_fairytale/features/clients/ui/client_latest_order_dialog.dart';

class ClientLastOrderView extends StatelessWidget {
  final Client client;
  final Future<ClientLatestOrder?> Function() loadOrder;

  const ClientLastOrderView({
    super.key,
    required this.client,
    required this.loadOrder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = client.latestOrderCreatedAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Последний заказ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        if (date == null)
          Text(
            'Заказов не было',
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else
          Row(
            children: [
              Flexible(
                child: Text(
                  date.toFormattedString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Открыть полный состав последнего заказа',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  mouseCursor: SystemMouseCursors.click,
                  hoverColor: theme.colorScheme.primary.withAlpha(20),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => ClientLatestOrderDialog(
                      createdAt: date,
                      loadOrder: loadOrder,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Посмотреть ›',
                      maxLines: 1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
