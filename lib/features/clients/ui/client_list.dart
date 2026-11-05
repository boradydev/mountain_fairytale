import 'package:mountain_fairytale/shared/widgets/app_notify.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_dialog.dart';
import 'package:mountain_fairytale/features/clients/ui/client_last_order.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class ClientsAttentionListView extends StatefulWidget {
  const ClientsAttentionListView({super.key});
  @override
  State<ClientsAttentionListView> createState() =>
      _ClientsAttentionListViewState();
}

class _ClientsAttentionListViewState extends State<ClientsAttentionListView> {
  final _search = TextEditingController();
  final _scroll = {
    for (final mode in ClientListMode.values) mode: ScrollController(),
  };
  Timer? _debounce;
  bool _initialized = false;
  bool _checkScheduled = false;
  final _states = <ClientListMode, DashboardClientsState>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _search.text = context.read<ClientsProvider>().search;
      for (final mode in ClientListMode.values) {
        _scroll[mode]!.addListener(() {
          final provider = context.read<ClientsProvider>();
          final state = provider.dashboardFor(mode);
          if (_states[mode] == state) {
            state.scrollOffset = _scroll[mode]!.offset;
          }
          if (provider.listMode == mode) _checkScroll();
        });
      }
    }
  }

  void _checkScroll() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    final provider = context.read<ClientsProvider>();
    final state = provider.dashboard;
    final controller = _scroll[provider.listMode]!;
    if (controller.hasClients &&
        controller.position.extentAfter < 250 &&
        !state.loading &&
        state.error.isEmpty &&
        state.hasMore) {
      unawaited(provider.loadDashboardClients());
    }
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final provider = context.read<ClientsProvider>();
      for (final mode in ClientListMode.values) {
        final state = provider.dashboardFor(mode);
        if (_states[mode] != state) {
          _states[mode] = state;
          final controller = _scroll[mode]!;
          if (controller.hasClients) controller.jumpTo(state.scrollOffset);
        }
      }
      _checkScroll();
    });
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) unawaited(context.read<ClientsProvider>().setSearch(value));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    for (final controller in _scroll.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientsProvider>();
    final colors = Theme.of(context).colorScheme;
    _scheduleCheck();
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .65),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Клиенты',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(height: 25),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = math.max(
                            1.0,
                            MediaQuery.textScalerOf(context).scale(14) / 14,
                          );
                          final width = constraints.maxWidth;
                          final selectorWidth = math.min(width, 365 * scale);
                          final filterWidth = math.min(width, 230 * scale);
                          final searchWidth =
                              width >= (365 + 230 + 300) * scale + 24
                              ? width - selectorWidth - filterWidth - 24
                              : math.min(width, 360 * scale);
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: selectorWidth,
                                child: SegmentedButton<ClientListMode>(
                                  direction: width < 365 * scale
                                      ? Axis.vertical
                                      : Axis.horizontal,
                                  showSelectedIcon: false,
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
                                  selected: {provider.listMode},
                                  onSelectionChanged: (selection) =>
                                      provider.setListMode(selection.single),
                                  style: SegmentedButton.styleFrom(
                                    selectedBackgroundColor: colors.primary,
                                    selectedForegroundColor: colors.onPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: filterWidth,
                                child: Visibility(
                                  visible:
                                      provider.listMode ==
                                      ClientListMode.database,
                                  maintainSize: true,
                                  maintainAnimation: true,
                                  maintainState: true,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: LabeledCheckboxToggle(
                                        label: 'Деактивированные',
                                        value: provider.showDeactivated,
                                        onChanged: provider.setShowDeactivated,
                                        tooltip: 'Показывать деактивированных клиентов вместе с активными',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: searchWidth,
                                child: TextField(
                                  controller: _search,
                                  maxLength: 500,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Клиент, адрес, уточнение или телефон',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    counterText: '',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: AppIconButton(
                                      icon: Icons.clear,
                                      tooltip: 'Очистить поиск',
                                      onPressed: () {
                                        _debounce?.cancel();
                                        _search.clear();
                                        unawaited(provider.setSearch(''));
                                      },
                                    ),
                                  ),
                                  onChanged: _searchChanged,
                                  onSubmitted: (value) {
                                    _debounce?.cancel();
                                    unawaited(provider.setSearch(value));
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: provider.listMode.index,
              children: [
                for (final mode in ClientListMode.values) _list(provider, mode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(ClientsProvider provider, ClientListMode mode) {
    final state = provider.dashboardFor(mode);
    final addCount = mode == ClientListMode.database ? 1 : 0;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleCheck();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await provider.refreshDashboardClients();
        },
        child: ListView.builder(
          controller: _scroll[mode],
          key: PageStorageKey(mode),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.clients.length + addCount + 1,
          itemBuilder: (context, index) {
            if (addCount == 1 && index == 0) return const _AddClientCard();
            final clientIndex = index - addCount;
            if (clientIndex < state.clients.length) {
              final client = state.clients[clientIndex];
              return _ClientAttentionCard(
                key: ValueKey(client.id),
                client: client,
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (state.loading) const CircularProgressIndicator(),
                  if (state.error.isNotEmpty) ...[
                    Text(state.error),
                    AppSecondaryButton(
                      text: 'Повторить',
                      onPressed: () {
                        if (state.refreshFailed) {
                          unawaited(provider.refreshDashboardClients());
                        } else {
                          unawaited(provider.loadDashboardClients());
                        }
                      },
                    ),
                  ] else if (state.initialized && state.clients.isEmpty)
                    Text(
                      mode == ClientListMode.followUp
                          ? 'Нет клиентов для обзвона.\nСейчас нет засыпающих клиентов без отложенного контакта.'
                          : 'Клиенты не найдены.',
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            );
          },
        ),
      ),
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

  const _ClientAttentionCard({super.key, required this.client});

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
                      child: ClientLastOrderView(client: client),
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

    // 2. У клиента ещё нет заказов ни с доставкой, ни с самовывозом.
    if (client.lastOrderDate == null) {
      return _ClientStatusConfig(
        lineColor: Colors.red.shade700,
        badgeBgColor: Colors.red.shade50,
        badgeTextColor: Colors.red.shade900,
        statusText: 'Заказов не было',
      );
    }

    // Вычисляем просрочку в днях и коэффициент K
    final differenceDays = client.daysSinceLastOrder(now)!;
    final k = client.sleepingThresholdDays == 0
        ? double.infinity
        : differenceDays / client.sleepingThresholdDays;

    // 3. Состояние: Критическое (Красный)
    if (k >= 3.0) {
      return _ClientStatusConfig(
        lineColor: Colors.red.shade700,
        badgeBgColor: Colors.red.shade50,
        badgeTextColor: Colors.red.shade900,
        statusText: 'Без заказов $differenceDays дн.',
      );
    }

    // 4. Состояние: Засыпает (Оранжевый)
    if (k >= 2.0) {
      return _ClientStatusConfig(
        lineColor: Colors.orange.shade700,
        badgeBgColor: Colors.orange.shade50,
        badgeTextColor: Colors.orange.shade900,
        statusText: 'Без заказов $differenceDays дн.',
      );
    }

    // 5. Состояние: Внимание (Желтый)
    if (k >= 1.0) {
      return _ClientStatusConfig(
        lineColor: Colors.amber.shade600,
        badgeBgColor: Colors.amber.shade50,
        badgeTextColor: Colors.amber.shade900,
        statusText: 'Без заказов $differenceDays дн.',
      );
    }

    // 6. Состояние: Норма (Зеленый)
    return const _ClientStatusConfig(
      lineColor: Colors.green,
      badgeBgColor: Color(0xFFE8F5E9), // Light green
      badgeTextColor: Color(0xFF1B5E20), // Dark green
      statusText: 'Заказывает регулярно',
    );
  }
}
