import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_dialog.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/select_delivery_type_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/metric_row_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/list_section_header.dart';
import 'package:provider/provider.dart';

class DeliveryDaysListView extends StatelessWidget {
  final ScrollController scrollController;
  final double? headerHeight;
  const DeliveryDaysListView({
    super.key,
    required this.scrollController,
    this.headerHeight,
  });
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryDaysProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListSectionHeader(
          height: headerHeight,
          title: 'Дни доставки',
          description: 'Маршруты и самовывозы по плановой дате.',
          controls: Text(
            'Загружено дней: ${provider.days.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refreshDeliveryDays,
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                AddActionButton(
                  label: 'Добавить доставку',
                  icon: Icons.add_circle_outline,
                  onTap: () async {
                    final type = await showDialog<DeliveryType>(
                      context: context,
                      builder: (_) => const SelectDeliveryTypeDialog(),
                    );
                    if (!context.mounted || type == null) return;
                    await openDayDocument(
                      context,
                      type,
                      DateTime.now(),
                      null,
                      () {
                        provider.refreshDeliveryDays();
                      },
                    );
                  },
                ),
                for (final day in provider.days)
                  DeliveryDayItem(key: ValueKey(day.plannedDate), day: day),
                if (provider.isLoadingMore ||
                    provider.status == DeliveryStatus.initial)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (provider.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          provider.errorMessage,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        AppSecondaryButton(
                          text: 'Повторить',
                          onPressed: provider.refreshDeliveryDays,
                        ),
                      ],
                    ),
                  )
                else if (provider.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Документов пока нет.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (provider.hasMore && !provider.isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppSecondaryButton(
                      text: 'Загрузить ещё',
                      onPressed: provider.fetchDeliveryDays,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DeliveryDayItem extends StatelessWidget {
  final DeliveryDay day;
  const DeliveryDayItem({super.key, required this.day});
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final colorScheme = Theme.of(context).colorScheme;
    final weekend =
        day.plannedDate.weekday == DateTime.saturday ||
        day.plannedDate.weekday == DateTime.sunday;
    return DeliveryDayCard(
      title:
          '${DateFormat.yMd(locale).format(day.plannedDate)} · ${DateFormat.EEEE(locale).format(day.plannedDate)}',
      titleSuffix: weekend
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Выходной',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            )
          : null,
      onTap: () {
        final provider = context.read<DeliveryDaysProvider>();
        showDialog<void>(
          context: context,
          builder: (_) =>
              DayDocumentsDialog(date: day.plannedDate, daysProvider: provider),
        );
      },
      metrics: [
        MetricRow(
          icon: Icons.local_shipping_outlined,
          label: 'Точки доставки',
          truncateLabel: true,
          value: '${day.deliveryPointsCount}',
        ),
        MetricRow(
          icon: Icons.store_outlined,
          label: 'Точки самовывоза',
          truncateLabel: true,
          value: '${day.pickupPointsCount}',
        ),
        for (final product in day.products)
          MetricRow(
            icon: Icons.shopping_bag_outlined,
            label: product.productName,
            truncateLabel: true,
            value: '${product.quantity} шт.',
          ),
        MetricRow(
          icon: Icons.payments_outlined,
          label: 'Оборот',
          truncateLabel: true,
          value: '${day.totalAmount.toStringAsFixed(2)} ₽',
          valueColor: colorScheme.primary,
        ),
      ],
    );
  }
}
