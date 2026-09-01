import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/models/delivery_day_model.dart';
import 'package:mountain_fairytale/infrastructure/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/presentation/providers/delivery_days_provider.dart';
import 'package:mountain_fairytale/presentation/providers/theme_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/card_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/locate_toggle_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/metric_row_widget.dart';
import 'package:provider/provider.dart';

class DeliveryDaysScreen extends StatefulWidget {
  const DeliveryDaysScreen({super.key});

  @override
  State<DeliveryDaysScreen> createState() => _DeliveryDaysScreenState();
}

class _DeliveryDaysScreenState extends State<DeliveryDaysScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryDaysProvider>().fetchDeliveryDays();
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<DeliveryDaysProvider>().fetchDeliveryDays();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select((ThemeProvider p) => p.isDarkMode);
    final l10n = AppLocalizations.of(context)!;

    // Точечно слушаем только статус загрузки для отображения нужного экрана
    final status = context.select((DeliveryDaysProvider p) => p.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: status == DeliveryStatus.loading
                ? null
                : () =>
                      context.read<DeliveryDaysProvider>().fetchDeliveryDays(),
          ),
          const LocaleToggleButton(),
          IconButton(
            icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
        ],
      ),
      body: switch (status) {
        DeliveryStatus.initial || DeliveryStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        DeliveryStatus.failure => _ErrorView(),
        DeliveryStatus.success =>
            _DeliveryDaysListView(
              scrollController: _scrollController,
            ),
      },
    );
  }
}

/// Изолированный список — не перерисовывает весь Scaffold при изменении элементов
class _DeliveryDaysListView extends StatelessWidget {
  final ScrollController scrollController;

  const _DeliveryDaysListView({
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final days = context.select(
          (DeliveryDaysProvider p) => p.days,
    );

    final hasMore = context.select(
          (DeliveryDaysProvider p) => p.hasMore,
    );

    final isLoadingMore = context.select(
          (DeliveryDaysProvider p) => p.isLoadingMore,
    );

    final shouldShowTodayCard = context.select(
          (DeliveryDaysProvider p) => p.shouldShowTodayCard,
    );

    final showLoader = hasMore && isLoadingMore;

    final todayCardCount = shouldShowTodayCard ? 1 : 0;
    final loaderCount = showLoader ? 1 : 0;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: todayCardCount + days.length + loaderCount,
      itemBuilder: (context, index) {
        // Первая карточка — "Добавить доставку на сегодня"
        if (shouldShowTodayCard && index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              child: const _TodayDeliveryCard(),
            ),
          );
        }

        // Смещаем индекс, если перед списком есть TodayDeliveryCard
        final dayIndex = index - todayCardCount;

        // Последний элемент — loader
        if (dayIndex == days.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final day = days[dayIndex];

        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
            ),
            child: _DeliveryDayItem(day: day),
          ),
        );
      },
    );
  }
}

/// Изолированная ячейка списка — полностью глупая, получает готовую модель
class _DeliveryDayItem extends StatelessWidget {
  final DeliveryDay day;

  const _DeliveryDayItem({required this.day});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final dateStr = day.date.toFormattedString();

    return DeliveryDayCard(
      title: day.date.isToday
          ? l10n.deliveryCardTitleToday
          : '${l10n.deliveryCardTitle}: $dateStr',
      onTap: () {
        // Логика перехода на детальный экран по day.id
      },
      metrics: [
        MetricRow(
          icon: Icons.people_outline_rounded,
          label: l10n.deliveryCardClients,
          value: '${day.clientsCount} ${l10n.deliveryCardClientsMetrics}',
        ),
        MetricRow(
          icon: Icons.water_drop_outlined,
          label: l10n.deliveryCardBottles,
          value: '${day.bottlesCount} ${l10n.deliveryCardBottlesMetrics}',
        ),
        MetricRow(
          icon: Icons.assignment_return_outlined,
          label: l10n.deliveryCardReturns,
          value: '${day.returnsCount} ${l10n.deliveryCardReturnsMetrics}',
          // Выделяем возвраты цветом ошибки, если они есть
          valueColor: day.returnsCount > 0 ? colorScheme.error : null,
        ),
        MetricRow(
          icon: Icons.wine_bar_outlined,
          label: l10n.deliveryCardGlasses,
          value: '${day.glassesCount} ${l10n.deliveryCardGlassesMetrics}',
        ),
        MetricRow(
          icon: Icons.kitchen_outlined,
          label: l10n.deliveryCardWaterCooler,
          value: '${day.waterCoolerCount} ${l10n.deliveryCardWaterCoolerMetrics}',
        ),
        MetricRow(
          icon: Icons.build_circle_outlined,
          label: l10n.deliveryCardCoolerRepair,
          value: '${day.coolerRepairCount} ${l10n.deliveryCardCoolerRepairMetrics}',
        ),
        MetricRow(
          icon: Icons.payments_outlined,
          label: l10n.deliveryCardTotal,
          value: '${day.totalAmount.toStringAsFixed(2)} ${l10n.deliveryCardTotalMetrics}',
          valueColor: colorScheme.primary,
        ),
      ],
    );
  }
}

/// Изолированный виджет ошибки
class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final errorMessage = context.select(
      (DeliveryDaysProvider p) => p.errorMessage,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  context.read<DeliveryDaysProvider>().fetchDeliveryDays(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayDeliveryCard extends StatelessWidget {
  const _TodayDeliveryCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    final l10n = AppLocalizations.of(context)!;

    return DeliveryDayCard(
      title: l10n.deliveryCardTitleToday,
      onTap: () {
        // TODO: открыть форму создания доставки
      },
      metrics: [
        Center(
          child: Column(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 40,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Добавить доставку',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}