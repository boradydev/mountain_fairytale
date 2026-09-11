import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/confirm_delete_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class CarDialog extends StatefulWidget {
  final Car? car;

  const CarDialog({super.key, this.car});

  @override
  State<CarDialog> createState() => _CarDialogState();
}

class _CarDialogState extends State<CarDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _modelController;
  late final TextEditingController _numberController;
  final _numberFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  Car? _duplicateCar;

  bool get _isEditMode => widget.car != null;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.car?.model ?? '');
    _numberController = TextEditingController(text: widget.car?.number ?? '');
    _numberFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_numberFocusNode.hasFocus) {
      _checkDuplicate();
    }
  }

  Future<void> _checkDuplicate() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) return;

    if (_isEditMode &&
        widget.car!.number.trim().toLowerCase() == number.toLowerCase()) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _duplicateCar = null;
      });
      return;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateCar = null;
    });

    final duplicate = await context
        .read<RouteConstructorProvider>()
        .checkCarDuplicate(number);

    if (!mounted) return;

    setState(() {
      _isCheckingDuplicate = false;
      _duplicateChecked = true;
      _duplicateCar = duplicate;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RouteConstructorProvider>();
    final model = _modelController.text.trim();
    final number = _numberController.text.trim();
    final bool success;

    if (_isEditMode) {
      success = await provider.updateCar(
        widget.car!.id,
        model: model,
        number: number,
      );
    } else {
      final created = await provider.addCar(model: model, number: number);
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

  Future<void> _deleteCar() async {
    if (widget.car == null) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      entityName: 'автомобиля «${widget.car!.model} (${widget.car!.number})»',
    );

    if (!confirmed || !mounted) return;

    final success = await context.read<RouteConstructorProvider>().deleteCar(
      widget.car!.id,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить автомобиль')),
      );
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _numberController.dispose();
    _numberFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseFormDialog(
      title: _isEditMode
          ? 'Редактирование автомобиля'
          : 'Добавление автомобиля',
      submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _submitForm,
      leadingAction: _isEditMode
          ? AppIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Удалить автомобиль',
              destructive: true,
              onPressed: _deleteCar,
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          hasDuplicate: _duplicateCar != null,
          warningText: _duplicateCar != null
              ? 'Найден похожий автомобиль: '
              '${_duplicateCar!.model}'
              '\nГосномер: ${_duplicateCar!.number}'
              : '',
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _modelController,
          decoration: const InputDecoration(
            labelText: 'Модель автомобиля *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_shipping_outlined),
            hintText: 'Газель Бизнес',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Введите модель';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _numberController,
          focusNode: _numberFocusNode,
          decoration: const InputDecoration(
            labelText: 'Госномер *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin_outlined),
            hintText: 'А123ББ',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty)
              return 'Введите госномер';
            return null;
          },
        ),
      ],
    );
  }
}
