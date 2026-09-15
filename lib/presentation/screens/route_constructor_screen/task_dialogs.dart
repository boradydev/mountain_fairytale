import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/product_dialog.dart';

class TaskDialogs {
  static Future<void> showAddTask(BuildContext context,
      RouteConstructorProvider provider,
      int pointIndex,) async {
    Product? selectedProduct;
    int quantity = 1;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Добавить позицию в задание',
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Product>(
                            hint: const Text(
                              'Выберите товар/услугу',
                            ),
                            initialValue: selectedProduct,
                            items: provider.products.map((product) {
                              return DropdownMenuItem<Product>(
                                value: product,
                                child: Text(
                                  '${product.name} '
                                      '(${product.basePrice} ₽)',
                                ),
                              );
                            }).toList(),
                            onChanged: (product) {
                              setDialogState(() {
                                selectedProduct = product;
                              });
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        IconButton(
                          tooltip: 'Добавить продукцию/услугу',
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final created = await showDialog<Product>(
                              context: context,
                              builder: (_) => const ProductDialog(),
                            );

                            if (created == null) {
                              return;
                            }

                            setDialogState(() {
                              selectedProduct = created;
                            });
                          },
                        ),

                        IconButton(
                          tooltip: 'Редактировать выбранную позицию',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: selectedProduct == null
                              ? null
                              : () async {
                            final productToEdit =
                            selectedProduct!;

                            await showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  ProductDialog(
                                    product: productToEdit,
                                  ),
                            );

                            // Получаем актуальную версию
                            // после редактирования.
                            final updated = provider.products
                                .where(
                                  (product) =>
                              product.id ==
                                  productToEdit.id,
                            )
                                .firstOrNull;

                            setDialogState(() {
                              selectedProduct = updated;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Количество:'),

                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: quantity > 1
                                  ? () {
                                setDialogState(() {
                                  quantity--;
                                });
                              }
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
                              onPressed: () {
                                setDialogState(() {
                                  quantity++;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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