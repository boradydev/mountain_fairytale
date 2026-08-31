import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/models/model.dart';
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
  @override
  void initState() {
    super.initState();
    // Инициируем загрузку данных при старте экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryDaysProvider>().fetchDeliveryDays();
    });
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
        DeliveryStatus.success => const _DeliveryDaysListView(),
      },
    );
  }
}

/// Изолированный список — не перерисовывает весь Scaffold при изменении элементов
class _DeliveryDaysListView extends StatelessWidget {
  const _DeliveryDaysListView();

  @override
  Widget build(BuildContext context) {
    // Вытаскиваем список дней. Больше этот виджет ничего не слушает.
    final days = context.select((DeliveryDaysProvider p) => p.days);

    if (days.isEmpty) {
      return const Center(child: Text('Список доставок пуст'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return _DeliveryDayItem(day: day);
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

    // Форматируем дату (можно вынести в расширение DateTime extension)
    final dateStr =
        '${day.date.day.toString().padLeft(2, '0')}.'
        '${day.date.month.toString().padLeft(2, '0')}.'
        '${day.date.year}';

    return DeliveryDayCard(
      title: '${l10n.deliveryCardTitle}: $dateStr',
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
          icon: Icons.local_drink_outlined,
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
          icon: Icons.payments_outlined,
          label: l10n.deliveryCardTotal,
          value: '${day.totalAmount.toStringAsFixed(2)} ',
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
