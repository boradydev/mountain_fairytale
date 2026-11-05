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
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .65),
            child: SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Material(
                  key: const ValueKey('delivery-days-panel'),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Дни доставки',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(height: 25),
                          Tooltip(
                            message: 'Календарные дни от первой даты документа, включая дни без доставок и запланированные даты.',
                            child: Text(
                              'Дней доставки: ${provider.status == DeliveryStatus.success || provider.days.isNotEmpty ? provider.total : '—'}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('delivery-days-loading-slot'),
            height: 3,
            child: provider.isRequesting
                ? const LinearProgressIndicator(minHeight: 3)
                : null,
          ),
          Expanded(
            child: RefreshIndicator.noSpinner(
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
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final date = DateFormat.yMd(locale).format(day.plannedDate);
    final weekday = DateFormat.EEEE(locale).format(day.plannedDate);
    return DeliveryDayCard(
      title: '$date · $weekday',
      titleSpan: TextSpan(
        children: [
          TextSpan(text: '$date · '),
          TextSpan(
            text: weekday,
            style: weekend
                ? TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE0A0BA)
                        : const Color(0xFF9A4568),
                  )
                : null,
          ),
        ],
      ),
      onTap: () {
        final provider = context.read<DeliveryDaysProvider>();
        showDialog<void>(
          context: context,
          builder: (_) => DayDocumentsDialog(
            date: day.plannedDate,
            daysProvider: provider,
          ),
        );
      },
      metrics: [
        MetricRow(
          icon: Icons.local_shipping_outlined,
          label: 'Клиенты доставки',
          truncateLabel: true,
          value: '${day.deliveryPointsCount}',
        ),
        MetricRow(
          icon: Icons.store_outlined,
          label: 'Клиенты самовывоза',
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
