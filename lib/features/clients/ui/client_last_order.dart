import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class ClientLastOrderView extends StatelessWidget {
  final Client client;

  const ClientLastOrderView({super.key, required this.client});

  String _remainingLabel(int count) {
    final lastTwo = count % 100;
    final last = count % 10;
    final word = lastTwo >= 11 && lastTwo <= 14
        ? 'позиций'
        : last == 1
        ? 'позиция'
        : last >= 2 && last <= 4
        ? 'позиции'
        : 'позиций';
    return 'ещё $count $word';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = client.lastOrder;
    final date = client.lastOrderDate;
    final dateLabel = date?.toFormattedString() ?? 'Заказов не было';
    final description = order == null
        ? dateLabel
        : '$dateLabel · ${order.fulfillmentLabel}';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Последний заказ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(description, style: theme.textTheme.bodyMedium),
        if (order != null && order.items.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            [
              ...order.items.take(2).map((item) => item.description),
              if (order.items.length > 2)
                _remainingLabel(order.items.length - 2),
            ].join(' · '),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
    if (order == null) return content;
    return Tooltip(
      message: 'Открыть полный состав последнего заказа',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Последний заказ'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(description),
                    const SizedBox(height: 16),
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(item.description),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              AppSecondaryButton(
                text: 'Закрыть',
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ),
        child: content,
      ),
    );
  }
}
