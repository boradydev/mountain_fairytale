import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';

class TaskDialogs {
  static void showAddTask(
    BuildContext context,
    RouteConstructorProvider provider,
    int pointIndex,
  ) {
    Product? selectedProduct;
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: const Text('Добавить позицию в задание'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Product>(
                    hint: const Text('Выберите товар/услугу'),
                    initialValue: selectedProduct,
                    items: provider.products.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (${p.basePrice} ₽)'),
                      );
                    }).toList(),
                    onChanged: (p) => setDialogState(() => selectedProduct = p),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Количество:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: quantity > 1
                                ? () => setDialogState(() => quantity--)
                                : null,
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setDialogState(() => quantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: selectedProduct == null
                      ? null
                      : () {
                          provider.addTaskToPoint(
                            pointIndex,
                            selectedProduct!,
                            quantity,
                          );
                          Navigator.pop(context);
                        },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
