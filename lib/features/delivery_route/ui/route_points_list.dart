import 'package:mountain_fairytale/features/delivery_route/ui/route_point_card_content.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_memo_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/failed_delivery_dialog.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
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

/// Expansion and scrolling belong to the open document, across form rebuilds.
class RoutePointsViewState {
  final _expandedClientIds = <String>{};
  double scrollOffset = 0;

  bool isExpanded(String clientId) => _expandedClientIds.contains(clientId);

  void setExpanded(String clientId, bool expanded) {
    if (expanded) {
      _expandedClientIds.add(clientId);
    } else {
      _expandedClientIds.remove(clientId);
    }
  }
}

class RoutePointsList extends StatefulWidget {
  final OrderPointsProvider provider;
  final RoutePointsViewState? viewState;

  const RoutePointsList({
    super.key,
    required this.provider,
    this.viewState,
  });

  @override
  State<RoutePointsList> createState() => _RoutePointsListState();
}

class _RoutePointsListState extends State<RoutePointsList> {
  late final ScrollController _scrollController;
  final _localViewState = RoutePointsViewState();
  RoutePointsViewState get _viewState => widget.viewState ?? _localViewState;

  int _lastPointsCount = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _viewState.scrollOffset,
      keepScrollOffset: false,
    )..addListener(_rememberScrollOffset);
  }

  void _rememberScrollOffset() {
    if (_scrollController.hasClients) {
      _viewState.scrollOffset = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _pointIndex(String viewId) => widget.provider.points.indexWhere(
    (point) => point.viewId == viewId,
  );

  Future<void> _editMemo(String viewId) async {
    final provider = widget.provider;
    final index = _pointIndex(viewId);
    if (!provider.canEdit || index < 0) return;
    final initialMemo = provider.points[index].memo;
    final memo = await showDialog<String>(
      context: context,
      builder: (_) => RoutePointMemoDialog(initialMemo: initialMemo),
    );
    if (!mounted || memo == null || !provider.canEdit) return;
    final currentIndex = _pointIndex(viewId);
    if (currentIndex >= 0) provider.setPointMemo(currentIndex, memo);
  }

  Future<void> _editReason(String viewId, {bool editing = false}) async {
    final provider = widget.provider;
    final index = _pointIndex(viewId);
    if (!provider.canEdit || index < 0) return;
    final initialReason = editing
        ? provider.points[index].nonDeliveryReason
        : '';
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => FailedDeliveryDialog(initialReason: initialReason),
    );
    if (!mounted || reason == null || !provider.canEdit) return;
    final currentIndex = _pointIndex(viewId);
    if (currentIndex >= 0) {
      provider.setDeliveryOutcome(
        currentIndex,
        delivered: false,
        reason: reason,
      );
    }
  }

  Widget _pointMenu(RoutePoint point) => PopupMenuButton<String>(
    tooltip: 'Действия с точкой',
    icon: const Icon(Icons.more_vert),
    onSelected: (action) {
      final provider = widget.provider;
      final index = _pointIndex(point.viewId);
      if (!provider.canEdit || index < 0) return;
      switch (action) {
        case 'memo':
          _editMemo(point.viewId);
        case 'outcome':
          if (provider.points[index].isDelivered) {
            _editReason(point.viewId);
          } else {
            provider.setDeliveryOutcome(index, delivered: true);
          }
        case 'delete':
          provider.removePoint(index);
      }
    },
    itemBuilder: (_) => [
      if (!widget.provider.isPickup) ...[
        PopupMenuItem(
          value: 'memo',
          child: Text(
            point.memo.isEmpty ? 'Добавить памятку' : 'Изменить памятку',
          ),
        ),
        PopupMenuItem(
          value: 'outcome',
          child: Text(
            point.isDelivered
                ? 'Отметить как недоставленное'
                : 'Снять отметку «Не доставлено»',
          ),
        ),
      ],
      PopupMenuItem(
        value: 'delete',
        child: Text(
          widget.provider.isPickup ? 'Удалить покупку' : 'Удалить точку',
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final viewState = _viewState;
    final colorScheme = Theme.of(context).colorScheme;
    final clientsProvider = provider.isPickup
        ? null
        : context.read<ClientsProvider>();

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
      return Center(
        child: Text(
          provider.isPickup
              ? 'Нажмите «Добавить покупку», чтобы добавить товары и способ оплаты.'
              : 'Добавьте клиентов из левой панели, чтобы составить маршрут объезда.',
        ),
      );
    }

    return _documentPointsList(
      controller: _scrollController,
      provider: provider,
      itemBuilder: (context, index) {
        final point = provider.points[index];

        return Padding(
          key: ValueKey(point.viewId),
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
                child: RoutePointCardSurface(
                  isDelivered: point.isDelivered,
                  child: ExpansionTile(
                    // Убираем появление девайдеров (линий) при разворачивании карточки
                    shape: const Border(),
                    collapsedShape: const Border(),
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    // ====================================
                    key: ValueKey('route-point-${point.viewId}'),
                    initiallyExpanded: viewState.isExpanded(point.viewId),
                    onExpansionChanged: (expanded) =>
                        viewState.setExpanded(point.viewId, expanded),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: RoutePointHeader(
                            point: point,
                            isPickup: provider.isPickup,
                            pickupTitle: 'Покупка ${index + 1}',
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          height: 48,
                          child: provider.canEdit ? _pointMenu(point) : null,
                        ),
                      ],
                    ),
                    leading: provider.isPickup
                        ? null
                        : ReorderableDragStartListener(
                            index: index,
                            enabled: provider.canEdit,
                            child: MouseRegion(
                              cursor: provider.canEdit
                                  ? SystemMouseCursors.grab
                                  : SystemMouseCursors.basic,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: provider.canEdit
                                      ? colorScheme.onSurfaceVariant
                                      : Theme.of(context).disabledColor,
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
                            if (!provider.isPickup) ...[
                              RoutePointNotes(
                                point: point,
                                onEditMemo: provider.canEdit
                                    ? () => _editMemo(point.viewId)
                                    : null,
                                onEditReason: provider.canEdit
                                    ? () => _editReason(
                                        point.viewId,
                                        editing: true,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final payment = PaymentMethodSelector(
                                  provider: provider,
                                  clientsProvider: clientsProvider,
                                  clientId: point.clientId,
                                  purchaseKey: provider.isPickup
                                      ? point.viewId
                                      : null,
                                  selectedId: point.documentPaymentMethodId,
                                  selectedName: point.documentPaymentMethodName,
                                );
                                if (provider.isPickup) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 360,
                                      ),
                                      child: payment,
                                    ),
                                  );
                                }
                                final representative =
                                    PointRepresentativeSelector(
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
                            const SizedBox(height: 8),
                            if (!provider.isPickup)
                              Text(
                                'Способ оплаты по умолчанию и представитель сохраняются у клиента сразу. Оплата точки — при сохранении документа.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: 24),

                            RoutePointTaskHeading(isPickup: provider.isPickup),

                            const SizedBox(height: 12),

                            RoutePointTaskTable(
                              items: point.items,
                              rowBuilder: (taskIndex) {
                                final item = point.items[taskIndex];
                                return TaskItemRow(
                                  key: ValueKey(
                                    item.itemId ??
                                        item.localId ??
                                        item.productId,
                                  ),
                                  enabled: provider.canEdit,
                                  allowFreePrice: !provider.isPickup,
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
                                      final confirmed = await ConfirmDialog.show(
                                        context,
                                        title: 'Обновить цену строки?',
                                        content:
                                            'Сохранённая цена: ${item.price} ₽. Цена каталога: ${product.basePrice} ₽. Количество останется прежним.',
                                        confirmText: 'Обновить цену',
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
                                  onPriceChanged: (price) =>
                                      provider.updateTaskPrice(
                                        index,
                                        taskIndex,
                                        price,
                                      ),
                                  onDriverNoteChanged: (note) =>
                                      provider.updateTaskDriverNote(
                                        index,
                                        taskIndex,
                                        note,
                                      ),
                                  onDelete: () => provider.removeTaskFromPoint(
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
                                );
                              },
                              footer: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final add = Visibility(
                                      visible: provider.canEdit,
                                      maintainSize: true,
                                      maintainAnimation: true,
                                      maintainState: true,
                                      child: AppSecondaryButton(
                                        icon: Icons.add,
                                        text: 'Добавить позицию',
                                        onPressed: provider.canEdit
                                            ? () => TaskDialogs.showAddTask(
                                                context,
                                                provider,
                                                index,
                                              )
                                            : null,
                                      ),
                                    );
                                    final total = Text(
                                      'Итого: ${point.totalAmount.toStringAsFixed(2)} ₽',
                                      style: TextStyle(
                                        decoration: point.isDelivered
                                            ? null
                                            : TextDecoration.lineThrough,
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
                                            alignment: Alignment.centerRight,
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

Widget _documentPointsList({
  required ScrollController controller,
  required OrderPointsProvider provider,
  required IndexedWidgetBuilder itemBuilder,
}) {
  if (provider.isPickup) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: provider.points.length,
      itemBuilder: itemBuilder,
    );
  }
  return ReorderableListView.builder(
    scrollController: controller,
    padding: const EdgeInsets.all(16),
    buildDefaultDragHandles: false,
    itemCount: provider.points.length,
    onReorderItem: (oldIndex, newIndex) => provider.reorderPoints(
      oldIndex,
      oldIndex < newIndex ? newIndex + 1 : newIndex,
    ),
    itemBuilder: itemBuilder,
  );
}
