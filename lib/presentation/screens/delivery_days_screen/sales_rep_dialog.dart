import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/confirm_delete_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class SalesRepDialog extends StatefulWidget {
  final SalesRepresentative? salesRep;

  const SalesRepDialog({super.key, this.salesRep});

  @override
  State<SalesRepDialog> createState() => _SalesRepDialogState();
}

class _SalesRepDialogState extends State<SalesRepDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _commissionPercentController;

  final _nameFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  SalesRepresentative? _duplicateRep;

  bool get _isEditMode => widget.salesRep != null;

  @override
  void initState() {
    super.initState();

    final salesRep = widget.salesRep;

    _nameController = TextEditingController(
      text: salesRep?.name ?? '',
    );

    _phoneController = TextEditingController(
      text: salesRep?.phone ?? '',
    );

    _commissionPercentController = TextEditingController(
      text: salesRep?.commissionPercent.toString() ?? '',
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
        widget.salesRep!.name.trim().toLowerCase() == name.toLowerCase()) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _duplicateRep = null;
      });
      return;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateRep = null;
    });

    final duplicate = await context
        .read<ClientsProvider>()
        .checkSalesRepDuplicate(name);

    if (!mounted) return;

    setState(() {
      _isCheckingDuplicate = false;
      _duplicateChecked = true;
      _duplicateRep = duplicate;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ClientsProvider>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final commissionPercent = double.parse(
      _commissionPercentController.text.trim().replaceAll(',', '.'),
    );
    final bool success;

    if (_isEditMode) {
      success = await provider.updateSalesRepresentative(
        widget.salesRep!.id,
        name,
        phone,
        commissionPercent,
      );
    } else {
      final created = await provider.addSalesRepresentative(
        name,
        phone,
        commissionPercent,
      );
      success = created != null;
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(success); // Возвращаем признак успеха
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить изменения')),
      );
    }
  }

  Future<void> _deleteSalesRep() async {
    if (widget.salesRep == null) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      entityName: 'представителя «${widget.salesRep!.name}»',
    );

    if (!confirmed || !mounted) return;

    final success = await context
        .read<ClientsProvider>()
        .deleteSalesRepresentative(widget.salesRep!.id);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(success);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить торгового представителя'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commissionPercentController.dispose();

    _nameFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseFormDialog(
      title: _isEditMode
          ? 'Редактирование представителя'
          : 'Добавление представителя',
      submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _submitForm,
      leadingAction: _isEditMode
          ? AppIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Удалить представителя',
              destructive: true,
              onPressed: _deleteSalesRep,
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          hasDuplicate: _duplicateRep != null,
          warningText: _duplicateRep != null
              ? 'Такой торговый представитель уже существует'
              : '',
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: const InputDecoration(
            labelText: 'ФИО представителя *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Введите ФИО';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Телефон представителя',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        TextFormField(
          controller: _commissionPercentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Вознаграждение',
            suffixText: '%',
          ),
          validator: (value) {
            if (value == null || value
                .trim()
                .isEmpty) {
              return 'Укажите процент';
            }

            final normalized = value.trim().replaceAll(',', '.');
            final percent = double.tryParse(normalized);

            if (percent == null) {
              return 'Введите число';
            }

            if (percent < 0 || percent > 100) {
              return 'Процент должен быть от 0 до 100';
            }

            return null;
          },
        ),
      ],
    );
  }
}
