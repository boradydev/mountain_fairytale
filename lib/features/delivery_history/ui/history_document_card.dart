import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/shared/widgets/document_summary_card.dart';

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
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DocumentSummaryCard(
            key: ValueKey('history-document-${doc.id}'),
            isPickup: doc.isPickup,
            title: doc.isPickup ? 'Самовывоз' : 'Доставка',
            date: _date.format(doc.plannedDate),
            createdAt: doc.createdAt == null
                ? 'Дата неизвестна'
                : DateFormat('dd.MM.yyyy HH:mm').format(doc.createdAt!),
            count: (doc.isPickup ? doc.purchasesCount : doc.clientsCount)
                .toString(),
            amount: _money.format(doc.totalAmount),
            driver: doc.driverName ?? 'Не указан',
            car: doc.carModelAndNumber ?? 'Не указана',
            isActive: doc.isActive,
            onOpen: onOpen,
          ),
        ),
      ),
    );
  }
}
