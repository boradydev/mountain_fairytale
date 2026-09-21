import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/presentation/providers/order_points_provider.dart';
import 'package:mountain_fairytale/presentation/screens/common/product_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/dropdown_widget.dart';

class TaskDialogs {
  static Future<void> showAddTask(
    BuildContext context,
    OrderPointsProvider provider,
    int pointIndex,
  ) async {
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
                    AppDropdown<Product>(
                      label: 'Продукция / услуга',
                      items: provider.products,
                      value: selectedProduct,
                      hint: 'Выберите товар/услугу',
                      itemLabelBuilder: (product) =>
                          '${product.name} (${product.basePrice} ₽)',
                      onChanged: (product) {
                        setDialogState(() {
                          selectedProduct = product;
                        });
                      },
                      onAdd: () async {
                        final created = await showDialog<Product>(
                          context: context,
                          builder: (_) => const ProductDialog(),
                        );

                        if (created != null) {
                          setDialogState(() {
                            selectedProduct = created;
                          });
                        }
                      },
                      onEdit: selectedProduct == null
                          ? null
                          : () async {
                              final productToEdit = selectedProduct!;

                              await showDialog<void>(
                                context: context,
                                builder: (_) => ProductDialog(
                                  product: productToEdit,
                                ),
                              );

                              // Получаем актуальную версию
                              // после редактирования или удаления.
                              Product? updated;

                              for (final product in provider.products) {
                                if (product.id == productToEdit.id) {
                                  updated = product;
                                  break;
                                }
                              }

                              setDialogState(() {
                                selectedProduct = updated;
                              });
                            },
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
