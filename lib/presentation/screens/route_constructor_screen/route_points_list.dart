import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/task_dialogs.dart';
import 'package:provider/provider.dart';

class RoutePointsList extends StatefulWidget {
  const RoutePointsList({super.key});

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
    final provider = context.watch<RouteConstructorProvider>();
    final colorScheme = Theme.of(context).colorScheme;

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
      onReorder: provider.reorderPoints,
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
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      point.clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${point.address} | Тел: ${point.phone}',
                    ),

                    // Справа оставляем отдельные действия:
                    // drag + delete.
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.drag_indicator,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Удалить точку',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => provider.removePoint(index),
                        ),
                      ],
                    ),

                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: point.paymentMethod,
                                    decoration: const InputDecoration(
                                      labelText: 'Форма оплаты',
                                      isDense: true,
                                    ),
                                    items: [
                                      'Наличные',
                                      'Безналичные (ООО/ИП)',
                                      'Карта',
                                    ].map((method) {
                                      return DropdownMenuItem(
                                        value: method,
                                        child: Text(method),
                                      );
                                    }).toList(),
                                    onChanged: (value) =>
                                        provider.updatePointMeta(
                                          index,
                                          paymentMethod: value,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                    point.salesRepresentative,
                                    decoration: const InputDecoration(
                                      labelText:
                                      'Торговый представитель',
                                      isDense: true,
                                    ),
                                    onChanged: (value) =>
                                        provider.updatePointMeta(
                                          index,
                                          salesRep: value,
                                        ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            const Text(
                              'Задание для водителя:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            ...point.items
                                .asMap()
                                .entries
                                .map((entry) {
                              final taskIndex = entry.key;
                              final item = entry.value;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.productName),
                                subtitle: Text(
                                  '${item.quantity} шт. × ${item.price} ₽',
                                ),
                                leading: IconButton(
                                  tooltip: 'Удалить позицию',
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      provider.removeTaskFromPoint(
                                        index,
                                        taskIndex,
                                      ),
                                ),
                                trailing: Text(
                                  '${item.amount.toStringAsFixed(2)} ₽',
                                ),
                              );
                            }),

                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text(
                                    'Добавить продукцию/услугу',
                                  ),
                                  onPressed: () =>
                                      TaskDialogs.showAddTask(
                                        context,
                                        provider,
                                        index,
                                      ),
                                ),
                                Text(
                                  'Итого по точке: '
                                      '${point.totalAmount.toStringAsFixed(
                                      2)} ₽',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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