// lib/presentation/screens/route_constructor_screen/payment_method_dialog.dart

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/models/payment_method_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/confirm_delete_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class PaymentMethodDialog extends StatefulWidget {
  final PaymentMethod? paymentMethod;

  const PaymentMethodDialog({super.key, this.paymentMethod});

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  PaymentMethod? _duplicateMethod;

  bool get _isEditMode => widget.paymentMethod != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.paymentMethod?.name ?? '',
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
    if (name.isEmpty) return;

    if (_isEditMode &&
        widget.paymentMethod!.name.trim().toLowerCase() == name.toLowerCase()) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _duplicateMethod = null;
      });
      return;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateMethod = null;
    });

    final duplicate = await context
        .read<RouteConstructorProvider>()
        .checkPaymentMethodDuplicate(name);

    if (!mounted) return;

    setState(() {
      _isCheckingDuplicate = false;
      _duplicateChecked = true;
      _duplicateMethod = duplicate;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RouteConstructorProvider>();
    final name = _nameController.text.trim();
    final bool success;

    if (_isEditMode) {
      success = await provider.updatePaymentMethod(
        widget.paymentMethod!.id,
        name,
      );
    } else {
      final created = await provider.addPaymentMethod(name);
      success = created != null;
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить изменения')),
      );
    }
  }

  Future<void> _deleteMethod() async {
    if (widget.paymentMethod == null) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      entityName: 'формы оплаты «${widget.paymentMethod!.name}»',
    );

    if (!confirmed || !mounted) return;

    final success = await context
        .read<RouteConstructorProvider>()
        .deletePaymentMethod(
          widget.paymentMethod!.id,
          widget.paymentMethod!.name,
        );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить форму оплаты')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseFormDialog(
      title: _isEditMode ? 'Редактирование оплаты' : 'Добавление формы оплаты',
      submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _submitForm,
      leadingAction: _isEditMode
          ? AppIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Удалить форму оплаты',
              destructive: true,
              onPressed: _deleteMethod,
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          hasDuplicate: _duplicateMethod != null,
          warningText: _duplicateMethod != null
              ? 'Такой способ оплаты уже существует'
              : '',
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: const InputDecoration(
            labelText: 'Наименование формы оплаты *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.payments_outlined),
            hintText: 'Например: СБП, Наложенный платеж',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите наименование';
            }
            return null;
          },
        ),
      ],
    );
  }
}
