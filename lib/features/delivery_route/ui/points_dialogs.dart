import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/products/ui/product_dialog.dart';
import 'package:mountain_fairytale/features/products/ui/product_activation_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class TaskDialogs {
  static Future<void> showAddTask(
    BuildContext context,
    OrderPointsProvider provider,
    int pointIndex,
  ) => showDialog<void>(
    context: context,
    builder: (_) => _AddTaskDialog(provider: provider, pointIndex: pointIndex),
  );
}

class _AddTaskDialog extends StatefulWidget {
  final OrderPointsProvider provider;
  final int pointIndex;
  const _AddTaskDialog({required this.provider, required this.pointIndex});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productFocusNode = FocusNode();
  String? _selectedId;
  int _quantity = 1;
  int _selectionVersion = 0;
  bool _busy = false;
  String? _error;

  Product? get _selected {
    for (final product in widget.provider.products) {
      if (product.id == _selectedId && product.isActive) {
        return product;
      }
    }
    return null;
  }

  Future<void> _toggleInactive(bool value) async {
    _productFocusNode.requestFocus();
    await widget.provider.toggleInactiveProducts(value);
  }

  Future<void> _select(Product? product) async {
    if (product == null || product.isActive) {
      setState(() {
        _selectedId = product?.id;
        _error = null;
      });
      return;
    }
    final confirmed = await showProductActivationDialog(context, product);
    if (!mounted) return;
    if (confirmed) {
      setState(() {
        _busy = true;
        _error = null;
      });
      final activated = await widget.provider.activateProduct(product);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (activated != null) {
          _selectedId = activated.id;
        } else {
          _error = 'Не удалось активировать товар. Повторите попытку.';
        }
      });
    }
    setState(() => _selectionVersion++);
  }

  Future<void> _showProductDialog({Product? product}) async {
    Product? openAfter;
    final result = await showDialog<Product>(
      context: context,
      builder: (dialogContext) => ProductDialog(
        provider: widget.provider,
        product: product,
        onOpenProduct: (existing) {
          openAfter = existing;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    if (!mounted) return;
    if (result != null) {
      widget.provider.includeActiveProduct(result);
      setState(() => _selectedId = result.id);
    }
    if (openAfter != null) {
      await _showProductDialog(product: openAfter);
    } else {
      setState(() => _selectionVersion++);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final product = _selected;
    if (product == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final added = await widget.provider.addCurrentProduct(
      widget.pointIndex,
      product.id,
      _quantity,
      productName: product.name,
    );
    if (!mounted) return;
    if (added) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = widget.provider.documentError;
      });
    }
  }

  @override
  void dispose() {
    _productFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final provider = widget.provider;
      return PopScope(
        canPop: !_busy,
        child: BaseFormDialog(
          title: 'Добавить позицию в задание',
          submitButtonText: 'Добавить',
          formKey: _formKey,
          onSubmit: _submit,
          isBusy: _busy,
          canSubmit: _selected != null,
          children: [
            AppDropdown<Product>(
              key: ValueKey('product-$_selectionVersion'),
              label: 'Продукция / услуга',
              focusNode: _productFocusNode,
              enabled: !_busy,
              showEdit: true,
              showAdd: true,
              editBeforeAdd: true,
              showInactiveToggle: true,
              includeInactive: provider.showInactiveProducts,
              onIncludeInactiveChanged: provider.isLoadingProducts
                  ? null
                  : _toggleInactive,
              items: provider.products,
              value: _selected,
              hint: 'Выберите товар/услугу',
              itemLabelBuilder: (product) =>
                  '${product.name} (${product.basePrice} ₽)',
              itemBuilder: (product) => Text(
                '${product.name} (${product.basePrice} ₽)${product.isActive ? '' : ' — Неактивен'}',
                overflow: TextOverflow.ellipsis,
                style: product.isActive
                    ? null
                    : TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              onChanged: _select,
              validator: (value) => value == null || !value.isActive
                  ? 'Выберите активный товар'
                  : provider.points[widget.pointIndex].items.any(
                      (item) => item.productId == value.id,
                    )
                  ? 'Товар уже добавлен. Измените количество строки.'
                  : null,
              onAdd: _busy ? null : () => _showProductDialog(),
              onEdit: _busy || _selected == null
                  ? null
                  : () => _showProductDialog(product: _selected),
            ),
            SizedBox(
              height: 4,
              child: provider.isLoadingProducts || _busy
                  ? const LinearProgressIndicator()
                  : null,
            ),
            if (provider.productLoadError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      provider.productLoadError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  AppSecondaryButton(
                    text: 'Повторить',
                    onPressed: provider.isLoadingProducts
                        ? null
                        : provider.loadProducts,
                  ),
                ],
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Количество:'),
                Row(
                  children: [
                    AppIconButton(
                      icon: Icons.remove,
                      tooltip: 'Уменьшить количество',
                      onPressed: _busy || _quantity <= 1
                          ? null
                          : () => setState(() => _quantity--),
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.add,
                      tooltip: 'Увеличить количество',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
