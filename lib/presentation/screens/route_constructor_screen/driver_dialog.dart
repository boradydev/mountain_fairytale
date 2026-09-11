import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/confirm_delete_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class DriverDialog extends StatefulWidget {
  final Driver? driver;

  const DriverDialog({super.key, this.driver});

  bool get isEditMode => driver != null;

  @override
  State<DriverDialog> createState() => _DriverDialogState();
}

class _DriverDialogState extends State<DriverDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  Driver? _duplicateDriver;

  bool get _isEditMode => widget.driver != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver?.name ?? '');
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
        widget.driver!.name.trim().toLowerCase() == name.toLowerCase()) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _duplicateDriver = null;
      });
      return;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateDriver = null;
    });

    final duplicate = await context
        .read<RouteConstructorProvider>()
        .checkDriverDuplicate(name);

    if (!mounted) return;

    setState(() {
      _isCheckingDuplicate = false;
      _duplicateChecked = true;
      _duplicateDriver = duplicate;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RouteConstructorProvider>();
    final name = _nameController.text.trim();
    final bool success;

    if (_isEditMode) {
      success = await provider.updateDriver(widget.driver!.id, name);
    } else {
      final created = await provider.addDriver(name);
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

  Future<void> _deleteDriver() async {
    if (widget.driver == null) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      entityName: 'водителя «${widget.driver!.name}»',
    );

    if (!confirmed || !mounted) return;

    final success = await context.read<RouteConstructorProvider>().deleteDriver(
      widget.driver!.id,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить водителя')),
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
      title: _isEditMode ? 'Редактирование водителя' : 'Добавление водителя',
      submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _submitForm,
      leadingAction: _isEditMode
          ? AppIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Удалить водителя',
              destructive: true,
              onPressed: _deleteDriver,
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          hasDuplicate: _duplicateDriver != null,
          warningText: _duplicateDriver != null
              ? 'Водитель уже существует: ${_duplicateDriver!.name}'
              : '',
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: const InputDecoration(
            labelText: 'ФИО водителя *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
            hintText: 'Иванов Иван Иванович',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите ФИО';
            }
            return null;
          },
        ),
      ],
    );
  }
}
