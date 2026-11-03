import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/dialog_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

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
                '${doc.isPickup ? 'Самовывоз' : 'Доставка'} · ${_date.format(doc.plannedDate)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!doc.isActive)
                Text(
                  'Отменён',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
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
          for (final purchase in doc.matchedClients) ...[
            const SizedBox(height: 12),
            AppDialogCard(
              key: ValueKey('history-purchase-${purchase.pointId}'),
              onTap: () => showHistoryPurchase(context, doc, purchase),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    purchase.clientName.isEmpty
                        ? 'Клиент (анонимный)'
                        : purchase.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (purchase.address.isNotEmpty) Text(purchase.address),
                  if (purchase.phone.isNotEmpty) Text(purchase.phone),
                  const SizedBox(height: 6),
                  Text(
                    purchase.items.isEmpty
                        ? 'Товаров нет'
                        : purchase.items
                              .take(2)
                              .map(
                                (item) =>
                                    '${item.productName} × ${item.quantity}',
                              )
                              .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (purchase.items.length > 2)
                    Text('Ещё позиций: ${purchase.items.length - 2}'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text('Покупка: ${_money.format(purchase.totalAmount)}'),
                      const Text(
                        'Подробнее о покупке',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showHistoryPurchase(
  BuildContext context,
  HistoryDocument document,
  HistoryPurchase purchase,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(
      purchase.clientName.isEmpty ? 'Клиент (анонимный)' : purchase.clientName,
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Плановая дата: ${_date.format(document.plannedDate)}'),
            if (!document.isActive) const Text('Документ отменён'),
            if (purchase.address.isNotEmpty) Text(purchase.address),
            if (purchase.phone.isNotEmpty) Text(purchase.phone),
            const SizedBox(height: 16),
            if (purchase.items.isEmpty) const Text('Товаров нет'),
            for (final item in purchase.items)
              AppDialogCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('${item.quantity} × ${_money.format(item.price)}'),
                    Text('Сумма: ${_money.format(item.amount)}'),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Итого: ${_money.format(purchase.totalAmount)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Способ оплаты: ${purchase.paymentMethodName ?? 'Не указан'}'),
          ],
        ),
      ),
    ),
    actions: [
      AppSecondaryButton(
        text: 'Закрыть',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  ),
);
