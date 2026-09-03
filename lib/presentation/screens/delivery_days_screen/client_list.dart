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

    // Карточка добавления отображается всегда, когда данные успешно загружены
    const addCardCount = 1;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // Общее количество элементов увеличивается на 1 из-за карточки создания
      itemCount: clients.length + addCardCount,
      itemBuilder: (context, index) {
        // Первым элементом (индекс 0) всегда выводим карточку создания клиента
        if (index == 0) {
          return const _AddClientCard();
        }

        // Для остальных элементов уменьшаем индекс на 1, чтобы не выйти за пределы массива
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

    // Проверяем, находится ли клиент на кулдауне прямо сейчас
    final isOnCooldown = client.cooldownUntil != null &&
        client.cooldownUntil!.isAfter(now);

    return AppBaseCard(
      onTap: () {
        // Логика перехода на детальный экран
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Строка с именем и кнопкой быстрых действий
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
              // Выпадающее меню выбора недель для десктопа
              PopupMenuButton<int>(
                icon: Icon(
                  Icons.access_time_rounded,
                  color: isOnCooldown ? colorScheme.primary : colorScheme
                      .onSurfaceVariant,
                ),
                tooltip: 'Отложить обработку',
                onSelected: (weeks) {
                  context.read<ClientsProvider>().updateClientCooldown(
                      client.id, weeks);
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
            ],
          ),

          // Маленький субтитр с адресом
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

          // Метрики
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
                  label: 'Доставка:',
                  labelWidth: 70,
                  value: client.lastDeliveryDate?.toFormattedString() ??
                      'никогда',
                ),
              ),
            ],
          ),

          // Если клиент уже отложен, выведем красивую плашку снизу карточки
          if (isOnCooldown) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      Icons.info_outline, size: 14, color: colorScheme.primary),
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
    );
  }
}
