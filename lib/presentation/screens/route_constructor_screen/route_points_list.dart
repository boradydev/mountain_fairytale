import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/task_dialogs.dart';
import 'package:provider/provider.dart';

class RoutePointsList extends StatelessWidget {
  const RoutePointsList({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteConstructorProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (provider.points.isEmpty) {
      return const Center(
        child: Text(
          'Добавьте клиентов из левой панели, чтобы составить маршрут объезда.',
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.points.length,
      onReorder: provider.reorderPoints,
      itemBuilder: (context, index) {
        final point = provider.points[index];

        return Container(
          key: ValueKey(point.clientId),
          // Ключ обязателен для работы Reorderable списка
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: Text('${index + 1}'), // Статичный порядковый номер
            ),
            title: Text(
              point.clientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${point.address} | Тел: ${point.phone}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => provider.removePoint(index),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Дополнительные параметры точки бизнес-аналитики
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: point.paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Форма оплаты',
                              isDense: true,
                            ),
                            items: ['Наличные', 'Безналичные (ООО/ИП)', 'Карта']
                                .map((m) {
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  );
                                })
                                .toList(),
                            onChanged: (v) => provider.updatePointMeta(
                              index,
                              paymentMethod: v,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: point.salesRepresentative,
                            decoration: const InputDecoration(
                              labelText: 'Торговый представитель',
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                provider.updatePointMeta(index, salesRep: v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Задание для водителя:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    // Перечисление номенклатуры (товаров/услуг)
                    ...point.items.asMap().entries.map((entry) {
                      final taskIdx = entry.key;
                      final item = entry.value;
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text(
                          '${item.quantity} шт. х ${item.price} ₽',
                        ),
                        trailing: Text('${item.amount.toStringAsFixed(2)} ₽'),
                        leading: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              provider.removeTaskFromPoint(index, taskIdx),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить продукцию/услугу'),
                          onPressed: () =>
                              TaskDialogs.showAddTask(context, provider, index),
                        ),
                        Text(
                          'Итого по точке: ${point.totalAmount.toStringAsFixed(2)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
