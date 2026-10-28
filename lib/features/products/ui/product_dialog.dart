import 'package:mountain_fairytale/core/state/form_editing.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/products/ui/product_activation_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class ProductDialog extends StatefulWidget {
  final OrderPointsProvider provider;
  final bool directoryMode;
  final Product? product;
  final ValueChanged<Product>? onOpenProduct;

  const ProductDialog({
    super.key,
    required this.provider,
    this.directoryMode = false,
    this.product,
    this.onOpenProduct,
  });

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _basePriceController;
  final _nameFocusNode = FocusNode();
  bool _busy = false;
  bool _checking = false;
  String? _checkedName;
  String? _error;
  Product? _duplicate;
  int _checkVersion = 0;

  bool get _isEditMode => widget.product != null;

  late final Map<String, Object?> _originalValues;
  late final String _originalDuplicateInput;
  late final DuplicateCheckCoordinator _duplicateCheck;
  Map<String, Object?> get _values => {
    'name': _nameController.text.trim(),
    'basePrice': formNumber(_basePriceController.text),
  };
  Map<String, Object?> get _changes =>
      changedFormFields(_originalValues, _values);
  String get _duplicateInput => _nameController.text.trim();
  bool get _needsDuplicateCheck =>
      !_isEditMode || _duplicateInput != _originalDuplicateInput;
  void _refreshForm() {
    if (mounted) setState(() {});
  }

  bool get _validDuplicateInput =>
      _nameController.text.trim().isNotEmpty &&
      _nameController.text.trim().length <= 120;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _basePriceController = TextEditingController(
      text: widget.product?.basePrice.toString() ?? '',
    );

    _originalValues = Map.of(_values);
    _originalDuplicateInput = _duplicateInput;
    _duplicateCheck = DuplicateCheckCoordinator(_duplicateInput);
    _basePriceController.addListener(_refreshForm);
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final changed = _duplicateCheck.inputChanged(
      _duplicateInput,
      canCheck:
          _needsDuplicateCheck &&
          _nameController.text.trim().isNotEmpty &&
          _nameController.text.trim().length <= 120,
      check: _checkDuplicate,
    );
    setState(() {
      if (changed) {
        _checkVersion++;
        _duplicate = null;
        _checkedName = null;
        _checking = false;
      }
      _error = null;
    });
  }

  Future<bool> _checkDuplicate() =>
      _duplicateCheck.run(_duplicateInput, _performDuplicateCheck);

  Future<bool> _performDuplicateCheck() async {
    if (!_needsDuplicateCheck) return true;
    if (_checkedName == _duplicateInput) return true;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 120) return false;
    final version = ++_checkVersion;
    if (_isEditMode && widget.product!.name == name) {
      setState(() {
        _checking = false;
        _checkedName = name;
        _duplicate = null;
      });
      return true;
    }
    setState(() {
      _checking = true;
      _checkedName = null;
      _duplicate = null;
      _error = null;
    });
    try {
      final duplicate = await widget.provider.checkProductDuplicate(name);
      if (!mounted || version != _checkVersion) return false;
      setState(() {
        _checking = false;
        _checkedName = name;
        _duplicate = duplicate?.id == widget.product?.id ? null : duplicate;
      });
      return true;
    } catch (_) {
      if (mounted && version == _checkVersion) {
        setState(() {
          _checking = false;
          _error = 'Не удалось проверить похожие товары. Повторите попытку.';
        });
      }
      return false;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_isEditMode && _changes.isEmpty) {
      Navigator.of(context).pop(widget.product);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _nameController.text.trim();
      if (_checkedName != name && !await _checkDuplicate()) return;
      if (!mounted) return;
      final duplicate = _duplicate;
      if (duplicate != null && duplicate.name == name) {
        if (!duplicate.isActive) {
          await _activate(duplicate);
        } else {
          setState(() {
            _error = 'Товар с таким названием уже существует. Откройте его для редактирования.';
          });
        }
        return;
      }
      final basePrice = double.parse(
        _basePriceController.text.trim().replaceAll(',', '.'),
      );
      Product? created;
      final bool success;
      if (_isEditMode) {
        success = await widget.provider.updateProduct(
          widget.product!.id,
          name: _changes['name'] as String?,
          basePrice: _changes['basePrice'] as double?,
        );
      } else {
        created = await widget.provider.addProduct(
          name: name,
          basePrice: basePrice,
        );
        success = created != null;
      }
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(created);
      } else {
        setState(() {
          _error =
              widget.provider.productErrorMessage ??
              'Не удалось сохранить товар.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate(Product product) async {
    final confirmed = await showProductActivationDialog(
      context,
      product,
      selectAfterActivation: !widget.directoryMode,
    );
    if (!confirmed || !mounted) return;
    final activated = await widget.provider.activateProduct(product);
    if (!mounted) return;
    if (activated != null) {
      Navigator.of(context).pop(activated);
    } else {
      setState(() {
        _error = 'Не удалось активировать товар. Повторите попытку.';
      });
    }
  }

  Future<void> _activateFromForm(Product product) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _activate(product);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    if (_busy) return;
    final product = widget.product!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Деактивировать товар?',
      content:
          '«${product.name}» станет недоступен для новых заданий. Запись и история сохранятся. Товар можно активировать снова.',
      confirmText: 'Деактивировать',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await widget.provider.setProductActive(product.id, false);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error =
            widget.provider.productErrorMessage ??
            'Не удалось деактивировать товар.';
      });
    }
  }

  @override
  void dispose() {
    _checkVersion++;
    _duplicateCheck.dispose();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _basePriceController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: BaseFormDialog(
      title: _isEditMode
          ? 'Редактирование продукции/услуги'
          : 'Добавление продукции/услуги',
      submitButtonText: _isEditMode
          ? (_changes.isEmpty ? 'ОК' : 'Сохранить')
          : 'Добавить',
      submitButtonWidth: 160,
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy,
      isLoading: _busy && !_checking,
      leadingAction: _isEditMode
          ? AppSecondaryButton(
              text: widget.product!.isActive
                  ? 'Деактивировать'
                  : 'Активировать',
              destructive: widget.product!.isActive,
              onPressed: _busy
                  ? null
                  : widget.product!.isActive
                  ? _deactivate
                  : () => _activateFromForm(widget.product!),
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          idleText: !_needsDuplicateCheck
              ? 'Поля проверки не изменены'
              : _validDuplicateInput
              ? 'Ожидание завершения ввода…'
              : 'Для проверки заполните название',
          isChecking: _checking,
          isChecked: _checkedName != null,
          hasDuplicate: _duplicate != null,
          warningText: _duplicate != null
              ? 'Найден похожий товар: ${_duplicate!.name} — ${_duplicate!.isActive ? 'Активен' : 'Неактивен'}. Похожее название разрешено; точное совпадение запрещено.'
              : '',
          expandedChild: _duplicate == null
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!widget.directoryMode || !_duplicate!.isActive)
                      AppPrimaryButton(
                        text: _duplicate!.isActive
                            ? 'Выбрать для задания'
                            : widget.directoryMode
                            ? 'Активировать'
                            : 'Активировать и выбрать',
                        onPressed: _busy
                            ? null
                            : () {
                                if (_duplicate!.isActive) {
                                  Navigator.of(context).pop(_duplicate);
                                } else {
                                  _activateFromForm(_duplicate!);
                                }
                              },
                      ),
                    AppSecondaryButton(
                      text: 'Открыть существующий товар',
                      onPressed: _busy || widget.onOpenProduct == null
                          ? null
                          : () => widget.onOpenProduct!(_duplicate!),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          enabled: !_busy,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Название *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory_2_outlined),
            hintText: 'Вода Горная 19л',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Введите название'
              : value.trim().length > 120
              ? 'Не более 120 символов'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _basePriceController,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Базовая цена *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_ruble),
            suffixText: '₽',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final price = double.tryParse(
              value?.trim().replaceAll(',', '.') ?? '',
            );
            if (price == null || !price.isFinite) {
              return 'Введите корректную цену';
            }
            if (price < 0 || price > 1000000000) {
              return 'Цена должна быть от 0 до 1 000 000 000 ₽';
            }
            return null;
          },
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
