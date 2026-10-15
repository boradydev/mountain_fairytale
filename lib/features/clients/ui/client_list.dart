import 'package:mountain_fairytale/shared/widgets/app_notify.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:mountain_fairytale/shared/widgets/list_section_header.dart';
import 'package:provider/provider.dart';

class ClientsAttentionListView extends StatelessWidget {
  final double? headerHeight;
  const ClientsAttentionListView({super.key, this.headerHeight});

  @override
  Widget build(BuildContext context) {
    final listMode = context.select(
      (ClientsProvider p) => p.listMode,
    );
    final colors = Theme.of(context).colorScheme;
    final showDeactivated = context.select(
      (ClientsProvider p) => p.showDeactivated,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListSectionHeader(
          height: headerHeight,
          title: 'Клиенты',
          description: listMode == ClientListMode.database
              ? 'База клиентов: добавление и редактирование данных.'
              : 'Засыпающие клиенты: обзвон и перенос следующего контакта.',
          controls: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
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
                if (listMode == ClientListMode.database) ...[
                  const SizedBox(width: 16),
                  LabeledCheckboxToggle(
                    label: 'Деактивированные',
                    value: showDeactivated,
                    onChanged: context
                        .read<ClientsProvider>()
                        .setShowDeactivated,
                    tooltip: 'Показывать деактивированных клиентов вместе с активными',
                  ),
                ],
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1),
        ),
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
      child: Container(
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusConfig.lineColor, width: 5),
          ),
        ),
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
                if (client.isActive)
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
                      final success = weeks == 0
                          ? await provider.resetClientCooldown(client.id)
                          : await provider.updateClientCooldown(
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
                          const PopupMenuItem<int>(
                            value: 4,
                            child: Text('Отложить на 4 недели'),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<int>(
                            value: 0,
                            enabled: client.cooldownUntil != null,
                            child: const Text('Сбросить отсрочку'),
                          ),
                        ],
                  ),
              ],
            ),
            Text(
              statusConfig.statusText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final wide = constraints.maxWidth >= 680 * scale;
                final width = constraints.maxWidth;
                final space = wide ? width - 24 : width;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: wide ? space * 0.24 : width,
                      child: _ClientCardField(
                        label: 'Телефон',
                        value: client.phone,
                      ),
                    ),
                    SizedBox(
                      width: wide ? space * 0.46 : width,
                      child: _ClientCardField(
                        label: 'Адрес',
                        value: client.address,
                      ),
                    ),
                    SizedBox(
                      width: wide ? space * 0.30 : width,
                      child: _ClientCardField(
                        label: 'Последняя доставка',
                        value:
                            client.lastDeliveryDate?.toFormattedString() ??
                            'Никогда',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCardField extends StatelessWidget {
  final String label;
  final String value;
  const _ClientCardField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, softWrap: true, style: theme.textTheme.bodyMedium),
      ],
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
    if (!client.isActive) {
      return const _ClientStatusConfig(
        lineColor: Colors.grey,
        badgeBgColor: Color(0xFFEEEEEE),
        badgeTextColor: Color(0xFF616161),
        statusText: 'Деактивирован',
      );
    }
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
