import 'package:mountain_fairytale/shared/widgets/app_notify.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/metric_row_widget.dart';
import 'package:provider/provider.dart';

class ClientsAttentionListView extends StatelessWidget {
  const ClientsAttentionListView({super.key});

  @override
  Widget build(BuildContext context) {
    final listMode = context.select(
      (ClientsProvider p) => p.listMode,
    );
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Клиенты',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SegmentedButton<ClientListMode>(
                    segments: const [
                      ButtonSegment(
                        value: ClientListMode.database,
                        label: Text('База клиентов'),
                        icon: Icon(Icons.people_outline),
                      ),
                      ButtonSegment(
                        value: ClientListMode.followUp,
                        label: Text('Обзвон клиентов'),
                        icon: Icon(Icons.phone_outlined),
                      ),
                    ],
                    selected: {listMode},
                    onSelectionChanged: (selection) => context
                        .read<ClientsProvider>()
                        .setListMode(selection.single),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: colors.primary,
                      selectedForegroundColor: colors.onPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                listMode == ClientListMode.database
                    ? 'Все клиенты: добавление и редактирование данных.'
                    : 'Засыпающие клиенты: обзвон и перенос следующего контакта.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildList(context)),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final status = context.select((ClientsProvider p) => p.status);

    if (status == ClientStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == ClientStatus.failure) {
      final error = context.select((ClientsProvider p) => p.errorMessage);
      return Center(child: Text('Ошибка: $error'));
    }

    final clients = context.select((ClientsProvider p) => p.sortedClients);

    final listMode = context.select(
      (ClientsProvider p) => p.listMode,
    );
    final isFollowUp = listMode == ClientListMode.followUp;

    // Добавление клиентов доступно в режиме ведения базы.
    final addCardCount = isFollowUp ? 0 : 1;

    if (clients.isEmpty && isFollowUp) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Нет клиентов для обзвона.\nСейчас нет засыпающих клиентов без отложенного контакта.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      key: PageStorageKey(listMode),
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
    return AddActionButton(
      label: 'Добавить клиента',
      icon: Icons.person_add_alt_1_outlined,
      onTap: () {
        showClientDialog(context);
      },
    );
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
        showClientDialog(context, client: client);
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
                        icon: Icon(
                          Icons.access_time_rounded,
                          color: statusConfig.badgeTextColor,
                        ),
                        tooltip: 'Отложить следующий контакт',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (weeks) async {
                          final provider = context.read<ClientsProvider>();
                          final success = await provider.updateClientCooldown(
                            client.id,
                            weeks,
                          );
                          if (!success && context.mounted) {
                            AppNotify.show(
                              provider.errorMessage,
                              isError: true,
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<int>>[
                              const PopupMenuItem<int>(
                                value: 1,
                                child: Text('Отложить на 1 неделю'),
                              ),
                              const PopupMenuItem<int>(
                                value: 2,
                                child: Text('Отложить на 2 недели'),
                              ),
                              const PopupMenuItem<int>(
                                value: 3,
                                child: Text('Отложить на 3 недели'),
                              ),
                            ],
                      ),
                      MetricRow(
                        label: 'Статус доставок:',
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
                          valueOverflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MetricRow(
                        label: 'Последняя доставка:',
                        value:
                            client.lastDeliveryDate?.toFormattedString() ??
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
    final differenceDays = now.difference(client.lastDeliveryDate!).inDays;
    final k = client.sleepingThresholdDays == 0
        ? double.infinity
        : differenceDays / client.sleepingThresholdDays;

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
