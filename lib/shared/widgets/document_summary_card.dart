import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/dialog_card_widget.dart';

/// Shared document summary. Callers format values and handle navigation.
class DocumentSummaryCard extends StatelessWidget {
  final bool isPickup;
  final String date;
  final String count;
  final String amount;
  final String driver;
  final String car;
  final bool isActive;
  final VoidCallback? onOpen;

  const DocumentSummaryCard({
    super.key,
    required this.isPickup,
    required this.date,
    required this.count,
    required this.amount,
    this.driver = 'Не указан',
    this.car = 'Не указан',
    this.isActive = true,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = <(String, String)>[
      ('Дата:', date),
      (isPickup ? 'Покупок:' : 'Клиентов:', count),
      ('Сумма:', amount),
      if (!isPickup) ...[('Водитель:', driver), ('Автомобиль:', car)],
    ];
    return AppDialogCard(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isPickup ? Icons.store_outlined : Icons.local_shipping_outlined,
            color: isActive ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  children: [
                    for (final (label, value) in details)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 12,
                              bottom: 4,
                            ),
                            child: Text(label),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Tooltip(
                              message: value,
                              child: Text(
                                value,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (!isActive)
                  Text('Отменён', style: TextStyle(color: colors.error)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
