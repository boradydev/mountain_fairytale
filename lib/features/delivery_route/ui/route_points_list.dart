import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/point_representative_selector.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/app_notify.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_selector.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/points_dialogs.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';
import 'package:provider/provider.dart';

class RoutePointsList extends StatefulWidget {
  final OrderPointsProvider provider;

  const RoutePointsList({
    super.key,
    required this.provider,
  });

  @override
  State<RoutePointsList> createState() => _RoutePointsListState();
}

class _RoutePointsListState extends State<RoutePointsList> {
  final ScrollController _scrollController = ScrollController();

  int _lastPointsCount = 0;
  bool _initialized = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final colorScheme = Theme.of(context).colorScheme;
    final clientsProvider = context.read<ClientsProvider>();

    if (!_initialized) {
      _lastPointsCount = provider.points.length;
      _initialized = true;
    } else if (provider.points.length > _lastPointsCount) {
      _lastPointsCount = provider.points.length;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    }

    if (provider.points.isEmpty) {
      return const Center(
        child: Text(
          'Добавьте клиентов из левой панели, чтобы составить маршрут объезда.',
        ),
      );
    }

    return ReorderableListView.builder(
      scrollController: _scrollController,
      padding: const EdgeInsets.all(16),
      buildDefaultDragHandles: false,
      itemCount: provider.points.length,
      onReorderItem: (oldIndex, newIndex) => provider.reorderPoints(
        oldIndex,
        oldIndex < newIndex ? newIndex + 1 : newIndex,
      ),
      itemBuilder: (context, index) {
        final point = provider.points[index];

        return Padding(
          key: ValueKey(point.clientId),
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Номер точки маршрута.
              // Это только отображение текущей позиции в списке.
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Container(
                  // Обрезает hover и splash эффекты строго по радиусу скругления corners
                  clipBehavior: Clip.antiAlias,
                  // =============================================
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                  child: ExpansionTile(
                    // Убираем появление девайдеров (линий) при разворачивании карточки
                    shape: const Border(),
                    collapsedShape: const Border(),
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    // ====================================
                    key: ValueKey('route-point-${point.clientId}'),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: LayoutBuilder(
                      builder: (context, constraints) {
                        final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              point.clientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              point.address,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        );
                        final summary = Column(
                          crossAxisAlignment: constraints.maxWidth < 440
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            Text(
                              point.items.isEmpty
                                  ? 'Задание не заполнено'
                                  : '${point.totalAmount.toStringAsFixed(2)} ₽',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: point.items.isEmpty
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${point.items.length} ${_positionsLabel(point.items.length)} · ${point.paymentMethod ?? 'Оплата не указана'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 440) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              details,
                              const SizedBox(height: 8),
                              summary,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: details),
                            const SizedBox(width: 20),
                            Flexible(child: summary),
                          ],
                        );
                      },
                    ),
                    leading: ReorderableDragStartListener(
                      index: index,
                      enabled: provider.canEdit,
                      child: MouseRegion(
                        cursor: provider.canEdit
                            ? SystemMouseCursors.grab
                            : SystemMouseCursors.basic,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Icon(
                            Icons.drag_indicator,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Телефон: ${point.phone}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ),
                                AppIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Удалить точку',
                                  destructive: true,
                                  onPressed: provider.canEdit
                                      ? () => provider.removePoint(index)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final payment = !provider.canEdit
                                    ? Text(
                                        'Способ оплаты: ${point.paymentMethod ?? 'Не указан'}',
                                      )
                                    : PaymentMethodSelector(
                                        provider: provider,
                                        clientsProvider: clientsProvider,
                                        clientId: point.clientId,
                                        selectedId: point.paymentMethodId,
                                        selectedName: point.paymentMethod,
                                      );
                                final representative = !provider.canEdit
                                    ? Text(
                                        'Торговый представитель: ${point.salesRepresentative}',
                                      )
                                    : PointRepresentativeSelector(
                                        provider: provider,
                                        point: point,
                                      );
                                if (constraints.maxWidth < 600) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      payment,
                                      const SizedBox(height: 16),
                                      representative,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: payment),
                                    const SizedBox(width: 16),
                                    Expanded(child: representative),
                                  ],
                                );
                              },
                            ),
                            if (provider.canEdit) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Изменения оплаты и представителя сохраняются в карточке клиента.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Задание для водителя',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (point.items.isNotEmpty)
                                    LayoutBuilder(
                                      builder: (context, constraints) =>
                                          constraints.maxWidth < 700
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 12,
                                                  ),
                                              child: DefaultTextStyle(
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium!,
                                                child: const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Продукция / услуга',
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 156,
                                                      child: Text(
                                                        'Количество',
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 112,
                                                      child: Text(
                                                        'Цена',
                                                        textAlign:
                                                            TextAlign.right,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 112,
                                                      child: Text(
                                                        'Сумма',
                                                        textAlign:
                                                            TextAlign.right,
                                                      ),
                                                    ),
                                                    SizedBox(width: 48),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    ),
                                  if (point.items.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 18,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Продукция или услуги не добавлены',
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ...point.items.asMap().entries.map((entry) {
                                      final taskIndex = entry.key;
                                      final item = entry.value;

                                      return Column(
                                        children: [
                                          TaskItemRow(
                                            key: ValueKey(item.productId),
                                            enabled: provider.canEdit,
                                            onRefreshPrice: () async {
                                              try {
                                                final product = await provider
                                                    .currentCatalogProduct(
                                                      item.productId,
                                                    );
                                                if (!context.mounted ||
                                                    !provider.canEdit) {
                                                  return;
                                                }
                                                if (!product.isActive) {
                                                  AppNotify.show(
                                                    'Нельзя обновить цену неактивного товара.',
                                                    isError: true,
                                                  );
                                                  return;
                                                }
                                                final confirmed =
                                                    await ConfirmDialog.show(
                                                      context,
                                                      title: 'Обновить цену строки?',
                                                      content:
                                                          'Сохранённая цена: ${item.price} ₽. Цена каталога: ${product.basePrice} ₽. Количество останется прежним.',
                                                      confirmText:
                                                          'Обновить цену',
                                                    );
                                                if (confirmed) {
                                                  provider.replaceItemPrice(
                                                    point,
                                                    item,
                                                    product,
                                                  );
                                                }
                                              } catch (_) {
                                                AppNotify.show(
                                                  'Не удалось загрузить цену каталога.',
                                                  isError: true,
                                                );
                                              }
                                            },
                                            index: taskIndex,
                                            item: item,
                                            onDelete: () =>
                                                provider.removeTaskFromPoint(
                                                  index,
                                                  taskIndex,
                                                ),
                                            onQuantityChanged: (quantity) {
                                              provider.updateTaskQuantity(
                                                index,
                                                taskIndex,
                                                quantity,
                                              );
                                            },
                                          ),
                                          if (taskIndex <
                                              point.items.length - 1)
                                            Divider(
                                              height: 1,
                                              thickness: 1,
                                              indent: 16,
                                              endIndent: 16,
                                              color: colorScheme.outlineVariant,
                                            ),
                                        ],
                                      );
                                    }),

                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: colorScheme.outlineVariant,
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final add = AppSecondaryButton(
                                          icon: Icons.add,
                                          text: 'Добавить позицию',
                                          onPressed: provider.canEdit
                                              ? () => TaskDialogs.showAddTask(
                                                  context,
                                                  provider,
                                                  index,
                                                )
                                              : null,
                                        );
                                        final total = Text(
                                          'Итого: ${point.totalAmount.toStringAsFixed(2)} ₽',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: colorScheme.onSurface,
                                          ),
                                        );
                                        if (constraints.maxWidth < 420) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              add,
                                              const SizedBox(height: 12),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: total,
                                              ),
                                            ],
                                          );
                                        }
                                        return Row(
                                          children: [
                                            add,
                                            const Spacer(),
                                            total,
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Вспомогательный метод для поиска в списке
extension ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    try {
      return firstWhere(test);
    } catch (_) {
      return null;
    }
  }
}

String _positionsLabel(int count) {
  if (count % 100 >= 11 && count % 100 <= 14) return 'позиций';
  return switch (count % 10) {
    1 => 'позиция',
    2 || 3 || 4 => 'позиции',
    _ => 'позиций',
  };
}
