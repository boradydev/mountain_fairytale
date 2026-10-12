import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_activation_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class PaymentMethodDialog extends StatefulWidget {
  final OrderPointsProvider provider;
  final PaymentMethod? paymentMethod;
  final ValueChanged<PaymentMethod>? onOpenPaymentMethod;

  const PaymentMethodDialog({
    super.key,
    required this.provider,
    this.paymentMethod,
    this.onOpenPaymentMethod,
  });

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  bool _busy = false;
  bool _checking = false;
  String? _checkedName;
  String? _error;
  String? _nameError;
  PaymentMethod? _duplicate;
  int _checkVersion = 0;

  bool get _isEditMode => widget.paymentMethod != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.paymentMethod?.name ?? '',
    );
    _nameController.addListener(_onNameChanged);
    _nameFocusNode.addListener(_onFocusChange);
  }

  void _onNameChanged() {
    _checkVersion++;
    setState(() {
      _duplicate = null;
      _checkedName = null;
      _checking = false;
      _error = null;
      _nameError = null;
    });
  }

  void _onFocusChange() {
    if (!_nameFocusNode.hasFocus && !_busy) _checkDuplicate();
  }

  Future<bool> _checkDuplicate() async {
    final name = _nameController.text;
    if (name.isEmpty || name.length > 120) return false;
    final version = ++_checkVersion;
    if (_isEditMode && widget.paymentMethod!.name == name) {
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
      final duplicate = await widget.provider.checkPaymentMethodDuplicate(name);
      if (!mounted || version != _checkVersion) return false;
      setState(() {
        _checking = false;
        _checkedName = name;
        _duplicate = duplicate?.id == widget.paymentMethod?.id
            ? null
            : duplicate;
      });
      return true;
    } catch (_) {
      if (mounted && version == _checkVersion) {
        setState(() {
          _checking = false;
          _error =
              'Не удалось проверить похожие способы оплаты. Повторите попытку.';
        });
      }
      return false;
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _nameController.text;
      if (_checkedName != name) await _checkDuplicate();
      if (!mounted) return;
      PaymentMethod? created;
      final bool success;
      if (_isEditMode) {
        success = await widget.provider.updatePaymentMethod(
          widget.paymentMethod!.id,
          name,
        );
      } else {
        created = await widget.provider.addPaymentMethod(
          name,
        );
        success = created != null;
      }
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(created);
      } else {
        setState(() {
          _nameError = widget.provider.paymentMethodNameError;
          _error = _nameError == null
              ? widget.provider.paymentMethodErrorMessage ??
                    'Не удалось сохранить способ оплаты.'
              : null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate(PaymentMethod paymentMethod) async {
    final confirmed = await showPaymentMethodActivationDialog(
      context,
      paymentMethod,
    );
    if (!confirmed || !mounted) return;
    final activated = await widget.provider.activatePaymentMethod(
      paymentMethod,
    );
    if (!mounted) return;
    if (activated != null) {
      Navigator.of(context).pop(activated);
    } else {
      setState(() {
        _error = 'Не удалось активировать способ оплаты. Повторите попытку.';
      });
    }
  }

  Future<void> _activateFromForm(PaymentMethod paymentMethod) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _activate(paymentMethod);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    if (_busy) return;
    final paymentMethod = widget.paymentMethod!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Деактивировать способ оплаты?',
      content:
          '«${paymentMethod.name}» станет недоступен для нового выбора. Запись и история сохранятся. Способ оплаты можно активировать снова.',
      confirmText: 'Деактивировать',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await widget.provider.setPaymentMethodActive(
      paymentMethod.id,
      false,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error =
            widget.provider.paymentMethodErrorMessage ??
            'Не удалось деактивировать способ оплаты.';
      });
    }
  }

  @override
  void dispose() {
    _checkVersion++;
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: BaseFormDialog(
      title: _isEditMode
          ? 'Редактирование способа оплаты'
          : 'Добавление способа оплаты',
      submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy,
      leadingAction: _isEditMode
          ? AppIconButton(
              icon: widget.paymentMethod!.isActive
                  ? Icons.archive_outlined
                  : Icons.check_circle_outline,
              tooltip: widget.paymentMethod!.isActive
                  ? 'Деактивировать способ оплаты'
                  : 'Активировать способ оплаты',
              destructive: widget.paymentMethod!.isActive,
              onPressed: _busy
                  ? null
                  : widget.paymentMethod!.isActive
                  ? _deactivate
                  : () => _activateFromForm(widget.paymentMethod!),
            )
          : null,
      children: [
        if (_busy) const LinearProgressIndicator(),
        DuplicateCheckStatusWidget(
          isChecking: _checking,
          isChecked: _checkedName != null,
          hasDuplicate: _duplicate != null,
          warningText: _duplicate != null
              ? 'Найден похожий способ оплаты: ${_duplicate!.name} — ${_duplicate!.isActive ? 'Активен' : 'Неактивен'}. Похожее название разрешено; точное совпадение запрещено.'
              : '',
          expandedChild: _duplicate == null
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPrimaryButton(
                      text: _duplicate!.isActive
                          ? 'Выбрать для клиента'
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
                      text: 'Открыть существующий способ оплаты',
                      onPressed: _busy || widget.onOpenPaymentMethod == null
                          ? null
                          : () => widget.onOpenPaymentMethod!(_duplicate!),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          forceErrorText: _nameError,
          focusNode: _nameFocusNode,
          enabled: !_busy,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Название *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.payments_outlined),
            hintText: 'Например: наличные, СБП',
            errorMaxLines: 2,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Введите название'
              : value.trim().length > 120
              ? 'Не более 120 символов'
              : null,
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
