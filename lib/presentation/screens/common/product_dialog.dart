import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/confirm_delete_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class ProductDialog extends StatefulWidget {
  final Product? product;

  const ProductDialog({super.key, this.product});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _basePriceController;

  final _nameFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  Product? _duplicateProduct;

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.product?.name ?? '');

    _basePriceController = TextEditingController(
      text: widget.product?.basePrice.toString() ?? '',
    );

    _nameFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_nameFocusNode.hasFocus) {
      _checkDuplicate();
    }
  }

  Future<void> _checkDuplicate() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    // В режиме редактирования не считаем сам объект дублем.
    if (_isEditMode &&
        widget.product!.name.trim().toLowerCase() == name.toLowerCase()) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _duplicateProduct = null;
      });
      return;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateProduct = null;
    });

    final duplicate = await context
        .read<RouteConstructorProvider>()
        .checkProductDuplicate(name);

    if (!mounted) return;

    // Дополнительная защита:
    // если найден именно редактируемый объект — это не дубль.
    final isSameProduct = _isEditMode && duplicate?.id == widget.product!.id;

    setState(() {
      _isCheckingDuplicate = false;
      _duplicateChecked = true;
      _duplicateProduct = isSameProduct ? null : duplicate;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Не разрешаем сохранение при найденном дубле.
    if (_duplicateProduct != null) {
      return;
    }

    final provider = context.read<RouteConstructorProvider>();

    final name = _nameController.text.trim();
    final basePrice = double.parse(
      _basePriceController.text.trim().replaceAll(',', '.'),
    );

    final bool success;
    Product? createdProduct;

    if (_isEditMode) {
      success = await provider.updateProduct(
        widget.product!.id,
        name: name,
        basePrice: basePrice,
      );
    } else {
      createdProduct = await provider.addProduct(
        name: name,
        basePrice: basePrice,
      );

      success = createdProduct != null;
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(createdProduct);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить изменения')),
      );
    }
  }

  Future<void> _deleteProduct() async {
    if (widget.product == null) {
      return;
    }

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      entityName: 'позиции «${widget.product!.name}»',
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await context
        .read<RouteConstructorProvider>()
        .deleteProduct(widget.product!.id);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить позицию')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _basePriceController.dispose();
    _nameFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseFormDialog(
      title: _isEditMode
          ? 'Редактирование продукции/услуги'
          : 'Добавление продукции/услуги',
      submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _submitForm,
      leadingAction: _isEditMode
          ? AppIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Удалить позицию',
              destructive: true,
              onPressed: _deleteProduct,
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          hasDuplicate: _duplicateProduct != null,
          warningText: _duplicateProduct != null
              ? 'Такая позиция уже существует: '
                    '${_duplicateProduct!.name}'
              : '',
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: const InputDecoration(
            labelText: 'Название *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory_2_outlined),
            hintText: 'Вода Горная 19л',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите название';
            }

            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _basePriceController,
          decoration: const InputDecoration(
            labelText: 'Базовая цена *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_ruble),
            suffixText: '₽',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите базовую цену';
            }

            final price = double.tryParse(value.trim().replaceAll(',', '.'));

            if (price == null) {
              return 'Введите корректную цену';
            }

            if (price < 0) {
              return 'Цена не может быть отрицательной';
            }

            return null;
          },
        ),
      ],
    );
  }
}
