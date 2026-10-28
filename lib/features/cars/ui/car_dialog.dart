import 'package:mountain_fairytale/core/state/form_editing.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/features/cars/ui/car_activation_dialog.dart';
import 'package:mountain_fairytale/features/cars/ui/car_number_input_formatter.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class CarDialog extends StatefulWidget {
  final Car? car;
  final bool directoryMode;
  final ValueChanged<Car>? onOpenCar;

  const CarDialog({
    super.key,
    this.car,
    this.onOpenCar,
    this.directoryMode = false,
  });

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

  late final Map<String, Object?> _originalValues;
  late final String _originalDuplicateInput;
  late final DuplicateCheckCoordinator _duplicateCheck;
  Map<String, Object?> get _values => {
    'model': _modelController.text.trim(),
    'number': canonicalCarNumber(_numberController.text),
    'currentMileage': _mileageController.text.trim().isEmpty
        ? (widget.car?.currentMileage ?? 0.0)
        : formNumber(_mileageController.text),
  };
  Map<String, Object?> get _changes =>
      changedFormFields(_originalValues, _values);
  String get _duplicateInput => canonicalCarNumber(_numberController.text);
  bool get _needsDuplicateCheck =>
      !_isEditMode || _duplicateInput != _originalDuplicateInput;
  void _refreshForm() {
    if (mounted) setState(() {});
  }

  bool get _validDuplicateInput => isValidCarNumber(_numberController.text);

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.car?.model ?? '');
    _numberController = TextEditingController(
      text: formatCarNumber(widget.car?.number ?? ''),
    );
    _mileageController = TextEditingController(
      text: widget.car?.currentMileage.toString() ?? '0',
    );
    _originalValues = Map.of(_values);
    _originalDuplicateInput = _duplicateInput;
    _duplicateCheck = DuplicateCheckCoordinator(_duplicateInput);
    _modelController.addListener(_refreshForm);
    _mileageController.addListener(_refreshForm);
    _numberController.addListener(_onNumberChanged);
  }

  void _onNumberChanged() {
    final changed = _duplicateCheck.inputChanged(
      _duplicateInput,
      canCheck:
          _needsDuplicateCheck && isValidCarNumber(_numberController.text),
      check: _checkDuplicate,
    );
    setState(() {
      if (changed) {
        _checkVersion++;
        _duplicateCar = null;
        _checkedNumber = null;
        _isCheckingDuplicate = false;
        _duplicateChecked = false;
      }
      _error = null;
    });
  }

  Future<bool> _checkDuplicate() =>
      _duplicateCheck.run(_duplicateInput, _performDuplicateCheck);

  Future<bool> _performDuplicateCheck() async {
    if (!_needsDuplicateCheck) return true;
    if (_checkedNumber == _duplicateInput) return true;
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
    if (_busy) return;
    if (_isEditMode && _changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
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
          formNumber(_mileageController.text) ??
          widget.car?.currentMileage ??
          0.0;
      final success = _isEditMode
          ? await provider.updateCar(
              widget.car!.id,
              model: _changes['model'] as String?,
              number: _changes['number'] as String?,
              currentMileage: _changes['currentMileage'] as double?,
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
    final confirmed = await showCarActivationDialog(
      context,
      car,
      selectAfterActivation: !widget.directoryMode,
    );
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
    _duplicateCheck.dispose();
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
      submitButtonText: _isEditMode
          ? (_changes.isEmpty ? 'ОК' : 'Сохранить')
          : 'Добавить',
      submitButtonWidth: 160,
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy,
      isLoading: _busy && !_isCheckingDuplicate,
      leadingAction: _isEditMode
          ? AppSecondaryButton(
              text: widget.car!.isActive ? 'Деактивировать' : 'Активировать',
              destructive: widget.car!.isActive,
              onPressed: _busy
                  ? null
                  : widget.car!.isActive
                  ? _deactivateCar
                  : () => _activateDuplicate(widget.car!),
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          idleText: !_needsDuplicateCheck
              ? 'Поля проверки не изменены'
              : _validDuplicateInput
              ? 'Ожидание завершения ввода…'
              : 'Для проверки заполните госномер',
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
                    if (!widget.directoryMode)
                      AppPrimaryButton(
                        text: 'Выбрать для маршрута',
                        onPressed: _busy
                            ? null
                            : () async {
                                await context
                                    .read<RouteConstructorProvider>()
                                    .selectExistingCar(_duplicateCar!);
                                if (!context.mounted) return;
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
              text: widget.directoryMode
                  ? 'Активировать'
                  : 'Активировать и выбрать',
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
              final mileage = formNumber(value);
              if (mileage == null || !mileage.isFinite || mileage < 0) {
                return 'Введите корректный пробег';
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
