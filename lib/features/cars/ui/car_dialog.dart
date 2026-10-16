import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/features/cars/ui/car_activation_dialog.dart';
import 'package:mountain_fairytale/features/cars/ui/car_number_input_formatter.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class CarDialog extends StatefulWidget {
  final Car? car;
  final ValueChanged<Car>? onOpenCar;

  const CarDialog({super.key, this.car, this.onOpenCar});

  @override
  State<CarDialog> createState() => _CarDialogState();
}

class _CarDialogState extends State<CarDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _modelController;
  late final TextEditingController _numberController;
  late final TextEditingController _mileageController;
  final _numberFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  bool _busy = false;
  Car? _duplicateCar;
  String? _checkedNumber;
  String? _error;
  int _checkVersion = 0;

  bool get _isEditMode => widget.car != null;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.car?.model ?? '');
    _numberController = TextEditingController(
      text: formatCarNumber(widget.car?.number ?? ''),
    )..addListener(_onNumberChanged);
    _mileageController = TextEditingController(
      text: widget.car?.currentMileage.toString() ?? '0',
    );
    _numberFocusNode.addListener(_onFocusChange);
  }

  void _onNumberChanged() {
    _checkVersion++;
    if (!mounted) return;
    setState(() {
      _duplicateCar = null;
      _duplicateChecked = false;
      _checkedNumber = null;
      _isCheckingDuplicate = false;
      _error = null;
    });
  }

  void _onFocusChange() {
    if (!_numberFocusNode.hasFocus && !_busy) _checkDuplicate();
  }

  Future<bool> _checkDuplicate() async {
    final number = canonicalCarNumber(_numberController.text);
    if (!isValidCarNumber(number)) return false;

    if (_isEditMode && canonicalCarNumber(widget.car!.number) == number) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _checkedNumber = number;
        _duplicateCar = null;
        _error = null;
      });
      return true;
    }

    final version = ++_checkVersion;
    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateCar = null;
      _error = null;
    });
    try {
      final duplicate = await context
          .read<RouteConstructorProvider>()
          .checkCarDuplicate(number);
      if (!mounted || version != _checkVersion) return false;
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _checkedNumber = number;
        _duplicateCar = duplicate?.id == widget.car?.id ? null : duplicate;
      });
      return true;
    } catch (_) {
      if (mounted && version == _checkVersion) {
        setState(() {
          _isCheckingDuplicate = false;
          _duplicateChecked = false;
          _error = 'Не удалось проверить номер. Проверьте соединение и повторите попытку.';
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
      final number = canonicalCarNumber(_numberController.text);
      if (_checkedNumber != number && !await _checkDuplicate()) return;
      if (!mounted) return;

      final duplicate = _duplicateCar;
      if (duplicate != null) {
        if (!duplicate.isActive) {
          await _activateDuplicate(duplicate);
        } else {
          setState(() {
            _error = 'Автомобиль с таким номером уже существует. Откройте его для редактирования.';
          });
        }
        return;
      }

      final provider = context.read<RouteConstructorProvider>();
      final model = _modelController.text.trim();
      final mileage =
          double.tryParse(_mileageController.text.trim()) ??
          widget.car?.currentMileage ??
          0.0;
      final success = _isEditMode
          ? await provider.updateCar(
              widget.car!.id,
              model: model,
              number: number,
              currentMileage: mileage,
            )
          : await provider.addCar(
                  model: model,
                  number: number,
                  currentMileage: mileage,
                ) !=
                null;

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error = 'Не удалось сохранить автомобиль. Возможно, этот номер уже занят.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activateDuplicate(Car car) async {
    final confirmed = await showCarActivationDialog(context, car);
    if (!confirmed || !mounted) return;
    final success = await context
        .read<RouteConstructorProvider>()
        .activateAndSelectCar(car);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(
        () => _error = 'Не удалось активировать автомобиль. Повторите попытку.',
      );
    }
  }

  Future<void> _deactivateCar() async {
    final car = widget.car;
    if (car == null || _busy) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Деактивировать автомобиль?',
      content:
          '«${car.model} (${formatCarNumber(car.number)})» станет недоступен для новых маршрутов. Запись и история сохранятся; автомобиль можно будет активировать снова.',
      confirmText: 'Деактивировать',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final success = await context
        .read<RouteConstructorProvider>()
        .deactivateCar(car.id);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = 'Не удалось деактивировать автомобиль. Повторите попытку.';
      });
    }
  }

  @override
  void dispose() {
    _checkVersion++;
    _modelController.dispose();
    _numberController
      ..removeListener(_onNumberChanged)
      ..dispose();
    _mileageController.dispose();
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
      onSubmit: _save,
      isBusy: _busy,
      isLoading: _busy && !_isCheckingDuplicate,
      leadingAction: _isEditMode && widget.car!.isActive
          ? AppIconButton(
              icon: Icons.archive_outlined,
              tooltip: 'Деактивировать автомобиль',
              destructive: true,
              onPressed: _busy ? null : _deactivateCar,
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          hasDuplicate: _duplicateCar != null,
          warningText: _duplicateCar != null
              ? 'Найден автомобиль: ${_duplicateCar!.model} (${formatCarNumber(_duplicateCar!.number)}) — ${_duplicateCar!.isActive ? 'Активен' : 'Неактивен'}'
              : '',
          expandedChild: _duplicateCar != null && _duplicateCar!.isActive
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPrimaryButton(
                      text: 'Выбрать для маршрута',
                      onPressed: _busy
                          ? null
                          : () {
                              context
                                  .read<RouteConstructorProvider>()
                                  .selectExistingCar(_duplicateCar!);
                              Navigator.of(context).pop();
                            },
                    ),
                    AppSecondaryButton(
                      text: 'Открыть существующий автомобиль',
                      onPressed: _busy
                          ? null
                          : () => widget.onOpenCar?.call(_duplicateCar!),
                    ),
                  ],
                )
              : null,
        ),
        if (_duplicateCar != null && !_duplicateCar!.isActive)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppPrimaryButton(
              text: 'Активировать и выбрать',
              onPressed: _busy
                  ? null
                  : () => _activateDuplicate(_duplicateCar!),
            ),
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _modelController,
          enabled: !_busy,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Модель автомобиля *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_shipping_outlined),
            hintText: 'Газель Бизнес',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Введите модель';
            if (value.trim().length > 100) return 'Не более 100 символов';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _numberController,
          focusNode: _numberFocusNode,
          enabled: !_busy,
          maxLength: 10,
          inputFormatters: const [CarNumberInputFormatter()],
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Госномер *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin_outlined),
            hintText: 'А123КХ 126',
            counterText: '',
          ),
          validator: (value) => isValidCarNumber(value ?? '')
              ? null
              : 'Введите номер в формате А123КХ 126',
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _mileageController,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Текущий пробег (км)',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              final mileage = double.tryParse(value);
              if (mileage == null || mileage < 0) {
                return 'Введите корректный пробег';
              }
              if (_isEditMode && mileage < widget.car!.currentMileage) {
                return 'Пробег не может быть меньше ${widget.car!.currentMileage}';
              }
            }
            return null;
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
