import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/models/delivery_day_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/models/delivery_day_product_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/pickup/models/pickup_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/product_contracts.dart';
import 'package:mountain_fairytale/presentation/providers/delivery_days_provider.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days_screen/select_delivery_type_dialog.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days_screen/select_route_dialog.dart';
import 'package:mountain_fairytale/presentation/screens/pickup_constructor_screen/pickup_constructor_screen.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/route_constructor_screen.dart';
import 'package:mountain_fairytale/presentation/widgets/add_action_card.dart';
import 'package:mountain_fairytale/presentation/widgets/card_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/metric_row_widget.dart';
import 'package:provider/provider.dart';

/// Изолированный список — не перерисовывает весь Scaffold при изменении элементов
class DeliveryDaysListView extends StatelessWidget {
  final ScrollController scrollController;

  const DeliveryDaysListView({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final days = context.select((DeliveryDaysProvider p) => p.days);

    final hasMore = context.select((DeliveryDaysProvider p) => p.hasMore);

    final isLoadingMore = context.select(
      (DeliveryDaysProvider p) => p.isLoadingMore,
    );

    final shouldShowTodayCard = context.select(
      (DeliveryDaysProvider p) => p.shouldShowTodayCard,
    );

    final showLoader = hasMore && isLoadingMore;

    final todayCardCount = shouldShowTodayCard ? 1 : 0;
    final loaderCount = showLoader ? 1 : 0;
    final l10n = AppLocalizations.of(context)!;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: todayCardCount + days.length + loaderCount,
      itemBuilder: (context, index) {
        // Первая карточка — "Добавить доставку на сегодня"
        if (shouldShowTodayCard && index == 0) {
          return AddActionButton(
            label: l10n.deliveryCardAddDelivery,
            icon: Icons.add_circle_outline,
            onTap: () async {
              final type = await showDialog<DeliveryType>(
                context: context,
                builder: (_) => const SelectDeliveryTypeDialog(),
              );

              if (!context.mounted || type == null) {
                return;
              }

              bool? isSaved;

              switch (type) {
                case DeliveryType.delivery:
                  isSaved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const RouteConstructorScreen(),
                    ),
                  );

                case DeliveryType.pickup:
                  isSaved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const PickupConstructorScreen(),
                    ),
                  );
              }

              if (isSaved == true && context.mounted) {
                context.read<DeliveryDaysProvider>().refreshDeliveryDays();
              }
            },
          );
        }

        // Смещаем индекс, если перед списком есть кнопка добавления
        final dayIndex = index - todayCardCount;

        // Последний элемент — loader
        if (dayIndex == days.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final day = days[dayIndex];

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

    final dateStr = day.date.toFormattedString();
    final labelWight = 300.0;

    return FutureBuilder<List<Product>>(
      future: context.read<ProductRepository>().getAvailableProducts(),
      builder: (context, snapshot) {
        final allProducts = snapshot.data ?? [];

        // Генерируем метрики для каждого продукта из общего списка
        final productMetrics = allProducts.map((product) {
          final dayProduct = day.products.firstWhere(
            (p) => p.productId == product.id,
            orElse: () =>
                DeliveryDayProduct(productId: product.id, quantity: 0),
          );

          return MetricRow(
            icon: Icons.shopping_bag_outlined,
            label: product.name,
            labelWidth: labelWight,
            value: '${dayProduct.quantity} шт.',
          );
        }).toList();

        return DeliveryDayCard(
          title: day.date.isToday
              ? l10n.deliveryCardTitleToday
              : '${l10n.deliveryCardTitle}: $dateStr',
          // Внутри метода onTap карточки _DeliveryDayItem:
          onTap: () async {
            final routeProvider = context.read<RouteConstructorProvider>();
            final pickupProvider = context.read<PickupConstructorProvider>();

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            // Получаем списки всех маршрутов и самовывозов за выбранный день
            final routes = await routeProvider.getRouteSheetsByDate(day.date);
            final pickups = await pickupProvider.getPickupSheetsByDate(
              day.date,
            );
            final allDocs = <RouteDocument>[...routes, ...pickups];

            if (context.mounted) {
              Navigator.of(context).pop(); // Закрываем лоадер
            }

            int? targetRouteId;
            RouteDocument? selectedDoc;

            if (allDocs.isEmpty) {
              // Если на этот день нет документов вообще (новый день)
              targetRouteId = null;
            } else if (allDocs.length == 1) {
              // Если документ один — сразу используем его
              selectedDoc = allDocs.first;
            } else if (allDocs.length > 1) {
              if (!context.mounted) return;

              // Открываем развилку выбора конкретного документа
              selectedDoc = await showDialog<RouteDocument>(
                context: context,
                builder: (context) => SelectRouteDialog(documents: allDocs),
              );

              if (selectedDoc == null) return; // Отмена выбора
            }

            if (!context.mounted) return;

            bool? isUpdated;

            if (selectedDoc is DeliveryRouteSheet) {
              // Переходим в конструктор маршрута
              isUpdated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) =>
                      RouteConstructorScreen(existingRouteId: selectedDoc?.id),
                ),
              );
            } else if (selectedDoc is PickupSheet) {
              // Переходим в конструктор самовывоза
              isUpdated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => PickupConstructorScreen(
                    existingPickupId: selectedDoc?.id,
                  ),
                ),
              );
            } else if (targetRouteId == null && allDocs.isEmpty) {
              // Создание нового маршрута по умолчанию, если ничего не найдено
              isUpdated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => const RouteConstructorScreen(),
                ),
              );
            }

            if (isUpdated == true && context.mounted) {
              context.read<DeliveryDaysProvider>().refreshDeliveryDays();
            }
          },

          metrics: [
            MetricRow(
              icon: Icons.people_outline_rounded,
              label: l10n.deliveryCardClients,
              labelWidth: labelWight,
              value: '${day.clientsCount} ${l10n.deliveryCardClientsMetrics}',
            ),
            ...productMetrics,
            MetricRow(
              icon: Icons.assignment_return_outlined,
              label: l10n.deliveryCardReturns,
              labelWidth: labelWight,
              value: '${day.returnsCount} ${l10n.deliveryCardReturnsMetrics}',
              // Выделяем возвраты цветом ошибки, если они есть
              valueColor: day.returnsCount > 0 ? colorScheme.error : null,
            ),
            MetricRow(
              icon: Icons.payments_outlined,
              label: l10n.deliveryCardTotal,
              labelWidth: labelWight,
              value:
                  '${day.totalAmount.toStringAsFixed(2)} ${l10n.deliveryCardTotalMetrics}',
              valueColor: colorScheme.primary,
            ),
          ],
        );
      },
    );
  }
}
