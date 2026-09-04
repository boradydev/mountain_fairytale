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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // Рассчитываем конфигурацию визуального статуса
    final statusConfig = _ClientStatusConfig.calculate(client, now);

    return AppBaseCard(
      onTap: () {
        // Логика перехода на детальный экран
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Левая цветная индикаторная линия
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: statusConfig.lineColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                      // Кнопка вызова меню откладывания
                      PopupMenuButton<int>(
                        icon: Icon(Icons.access_time_rounded,
                          color: statusConfig.badgeTextColor,),
                        tooltip: 'Отложить обработку',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (weeks) {
                          context.read<ClientsProvider>().updateClientCooldown(
                              client.id, weeks);
                        },
                        itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<int>>[
                          const PopupMenuItem<int>(
                              value: 1, child: Text('Отложить на 1 неделю')),
                          const PopupMenuItem<int>(
                              value: 2, child: Text('Отложить на 2 недели')),
                          const PopupMenuItem<int>(
                              value: 3, child: Text('Отложить на 3 недели')),
                        ],
                      ),
                      MetricRow(label: 'Статус доставок:',
                        value: statusConfig.statusText,
                        valueWidth: 170,
                      ),

                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(color: colorScheme.outlineVariant, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      MetricRow(
                        label: 'Телефон:',
                        value: client.phone,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricRow(
                          label: 'Адрес:',
                          value: client.address,
                        ),
                      ),
                      MetricRow(
                        label: 'Последняя доставка:',
                        value: client.lastDeliveryDate?.toFormattedString() ??
                            'никогда',
                        valueWidth: 170,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientStatusConfig {
  final Color lineColor; // Цвет полоски справа
  final Color badgeBgColor; // Фон плашки статуса
  final Color badgeTextColor; // Цвет текста плашки
  final String statusText; // Сам текст статуса

  const _ClientStatusConfig({
    required this.lineColor,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.statusText,
  });

  factory _ClientStatusConfig.calculate(Client client, DateTime now) {
    // 1. Состояние: Режим ожидания (Кулдаун) — высший приоритет для отображения
    final cooldownUntil = client.cooldownUntil;
    if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
      return const _ClientStatusConfig(
        lineColor: Colors.blue,
        badgeBgColor: Color(0xFFE3F2FD), // Light blue
        badgeTextColor: Color(0xFF0D47A1), // Dark blue
        statusText: 'В режиме ожидания',
      );
    }

    // 2. Состояние: Доставок вообще никогда не было
    if (client.lastDeliveryDate == null) {
      return _ClientStatusConfig(
        lineColor: Colors.red.shade700,
        badgeBgColor: Colors.red.shade50,
        badgeTextColor: Colors.red.shade900,
        statusText: 'Доставок не было',
      );
    }

    // Вычисляем просрочку в днях и коэффициент K
    final differenceDays = now
        .difference(client.lastDeliveryDate!)
        .inDays;
    final k = differenceDays / client.sleepingThresholdDays;

    // 3. Состояние: Критическое (Красный)
    if (k >= 3.0) {
      return _ClientStatusConfig(
        lineColor: Colors.red.shade700,
        badgeBgColor: Colors.red.shade50,
        badgeTextColor: Colors.red.shade900,
        statusText: 'Без доставки $differenceDays дн.',
      );
    }

    // 4. Состояние: Засыпает (Оранжевый)
    if (k >= 2.0) {
      return _ClientStatusConfig(
        lineColor: Colors.orange.shade700,
        badgeBgColor: Colors.orange.shade50,
        badgeTextColor: Colors.orange.shade900,
        statusText: 'Без доставки $differenceDays дн.',
      );
    }

    // 5. Состояние: Внимание (Желтый)
    if (k >= 1.0) {
      return _ClientStatusConfig(
        lineColor: Colors.amber.shade600,
        badgeBgColor: Colors.amber.shade50,
        badgeTextColor: Colors.amber.shade900,
        statusText: 'Без доставки $differenceDays дн.',
      );
    }

    // 6. Состояние: Норма (Зеленый)
    return const _ClientStatusConfig(
      lineColor: Colors.green,
      badgeBgColor: Color(0xFFE8F5E9), // Light green
      badgeTextColor: Color(0xFF1B5E20), // Dark green
      statusText: 'Доставляем регулярно',
    );
  }
}

