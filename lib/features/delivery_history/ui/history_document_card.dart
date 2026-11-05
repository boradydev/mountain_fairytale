import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';

final _money = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');
final _date = DateFormat('dd.MM.yyyy');

class HistoryDocumentCard extends StatelessWidget {
  final HistoryDocument document;
  final VoidCallback onOpen;
  const HistoryDocumentCard({
    super.key,
    required this.document,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final doc = document;
    return AppBaseCard(
      key: ValueKey('history-document-${doc.id}'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                doc.isPickup ? 'Самовывоз' : 'Доставка',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!doc.isActive)
                Text(
                  'Отменён',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          Text('Плановая дата: ${_date.format(doc.plannedDate)}'),
          Text(
            'Создан: ${doc.createdAt == null ? 'Дата неизвестна' : DateFormat('dd.MM.yyyy HH:mm').format(doc.createdAt!)}',
          ),
          const SizedBox(height: 8),
          if (!doc.isPickup) ...[
            Text('Водитель: ${doc.driverName ?? 'Не указан'}'),
            Text('Машина: ${doc.carModelAndNumber ?? 'Не указана'}'),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 24,
            runSpacing: 4,
            children: [
              Text(
                'Сумма документа: ${_money.format(doc.totalAmount)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                doc.isPickup
                    ? 'Покупок: ${doc.purchasesCount}'
                    : 'Клиентов: ${doc.clientsCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
