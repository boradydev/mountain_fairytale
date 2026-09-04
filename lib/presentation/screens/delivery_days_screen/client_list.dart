import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/add_action_card.dart';
import 'package:mountain_fairytale/presentation/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/metric_row_widget.dart';
import 'package:provider/provider.dart';


class ClientsAttentionListView extends StatelessWidget {
  const ClientsAttentionListView({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select((ClientsProvider p) => p.status);

    if (status == ClientStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == ClientStatus.failure) {
      final error = context.select((ClientsProvider p) => p.errorMessage);
      return Center(child: Text('Ошибка: $error'));
    }

    final clients = context.select((ClientsProvider p) => p.sortedClients);

    // Читаем из провайдера, включен ли сейчас фильтр просрочки
    final showOnlySleeping = context.select((ClientsProvider p) =>
    p.showOnlySleeping);

    // Если фильтр включен — карточку добавления НЕ показываем (count = 0), иначе показываем (count = 1)
    final addCardCount = showOnlySleeping ? 0 : 1;

    if (clients.isEmpty && showOnlySleeping) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Все клиенты в порядке!\nПросроченных нет.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: clients.length + addCardCount,
      itemBuilder: (context, index) {
        // Если карточка добавления активна и это самый первый элемент
        if (addCardCount == 1 && index == 0) {
          return const _AddClientCard();
        }

        // Смещаем индекс на addCardCount (0 или 1), чтобы правильно читать массив
        final client = clients[index - addCardCount];
        return _ClientAttentionCard(client: client);
      },
    );
  }
}

/// Новая карточка для добавления клиента (встает в самое начало списка)
class _AddClientCard extends StatelessWidget {
  const _AddClientCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    // Опционально: можно вытянуть из l10n, когда добавите строку
    // final l10n = AppLocalizations.of(context)!;

    return AddActionButton(label: 'Добавить клиента',
        icon: Icons.person_add_alt_1_outlined,
        onTap: () {
          // TODO: Логика добавления клиента
        });
  }
}

class _ClientAttentionCard extends StatelessWidget {
  final Client client;

  const _ClientAttentionCard({required this.client});

  // Метод определения цвета в зависимости от коэффициента просрочки
  Color? _getUrgencyColor(BuildContext context, Client client) {
    if (client.lastDeliveryDate == null)
      return Colors.red.shade700; // Никогда не покупал

    final now = DateTime.now();
    final differenceDays = now
        .difference(client.lastDeliveryDate!)
        .inDays;
    final k = differenceDays / client.sleepingThresholdDays;

    if (k >= 3.0) return Colors.red.shade700; // x3 и более
    if (k >= 2.0) return Colors.orange.shade700; // x2 - x3
    if (k >= 1.0) return Colors.amber.shade600; // x1 - x2 (желтый/янтарный)

    return null; // Нет просрочки, цвет не нужен
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isOnCooldown = client.cooldownUntil != null &&
        client.cooldownUntil!.isAfter(now);

    // Получаем цвет индикатора (если клиент на кулдауне — индикатор скрываем или делаем серым)
    final indicatorColor = isOnCooldown ? null : _getUrgencyColor(
        context, client);

    return AppBaseCard(
      onTap: () {
        // Логика перехода на детальный экран
      },
      child: IntrinsicHeight( // Чтобы цветная полоска растягивалась по всей высоте содержимого
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Левый цветной маркер срочности
            if (indicatorColor != null) ...[
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Основной контент карточки
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          client.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      PopupMenuButton<int>(
                        icon: Icon(
                          Icons.access_time_rounded,
                          color: isOnCooldown
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Отложить обработку',
                        onSelected: (weeks) {
                          context.read<ClientsProvider>().updateClientCooldown(
                              client.id, weeks);
                        },
                        itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<int>>[
                          const PopupMenuItem<int>(value: 1, child: Text(
                              'Отложить на 1 неделю')),
                          const PopupMenuItem<int>(value: 2, child: Text(
                              'Отложить на 2 недели')),
                          const PopupMenuItem<int>(value: 3, child: Text(
                              'Отложить на 3 недели')),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    client.address,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant.withAlpha(200),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: colorScheme.outlineVariant, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: MetricRow(
                          label: 'Телефон:',
                          labelWidth: 65,
                          value: client.phone,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: MetricRow(
                          label: 'Последняя доставка:',
                          labelWidth: 140,
                          value: client.lastDeliveryDate?.toFormattedString() ??
                              'никогда',
                        ),
                      ),
                    ],
                  ),
                  if (isOnCooldown) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withAlpha(100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 14, color: colorScheme
                              .primary),
                          const SizedBox(width: 6),
                          Text(
                            'В режиме ожидания до: ${client.cooldownUntil!
                                .toFormattedString()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

