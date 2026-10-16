import 'package:mountain_fairytale/core/state/form_editing.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/drivers/ui/driver_activation_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class DriverDialog extends StatefulWidget {
  final Driver? driver;
  final ValueChanged<Driver>? onOpenDriver;
  const DriverDialog({super.key, this.driver, this.onOpenDriver});
  bool get isEditMode => driver != null;
  @override
  State<DriverDialog> createState() => _DriverDialogState();
}

class _DriverDialogState extends State<DriverDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  bool _busy = false;
  bool _checking = false;
  String? _error;
  String? _checkedName;
  Driver? _duplicate;
  int _checkVersion = 0;

  late final Map<String, Object?> _originalValues;
  late final String _originalDuplicateInput;
  late final DuplicateCheckCoordinator _duplicateCheck;
  Map<String, Object?> get _values => {'name': _nameController.text.trim()};
  Map<String, Object?> get _changes =>
      changedFormFields(_originalValues, _values);
  String get _duplicateInput => _nameController.text.trim();
  bool get _needsDuplicateCheck =>
      !widget.isEditMode || _duplicateInput != _originalDuplicateInput;

  bool get _validDuplicateInput =>
      _nameController.text.trim().isNotEmpty &&
      _nameController.text.trim().length <= 120;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver?.name ?? '');

    _originalValues = Map.of(_values);
    _originalDuplicateInput = _duplicateInput;
    _duplicateCheck = DuplicateCheckCoordinator(_duplicateInput);
    _nameController.addListener(_onDuplicateInputChanged);
  }

  void _onDuplicateInputChanged() {
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
        _error = null;
      }
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
    setState(() {
      _checking = true;
      _checkedName = null;
      _duplicate = null;
      _error = null;
    });
    try {
      final duplicate = await context
          .read<RouteConstructorProvider>()
          .checkDriverDuplicate(name);
      if (!mounted || version != _checkVersion) return false;
      setState(() {
        _checking = false;
        _checkedName = name;
        _duplicate = duplicate?.id == widget.driver?.id ? null : duplicate;
      });
      return true;
    } catch (_) {
      if (mounted && version == _checkVersion) {
        setState(() {
          _checking = false;
          _error = 'Не удалось проверить похожие имена. Повторите попытку.';
        });
      }
      return false;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (widget.isEditMode && _changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<RouteConstructorProvider>();
    setState(() => _busy = true);
    try {
      if (_needsDuplicateCheck && _checkedName != _duplicateInput) {
        if (!await _checkDuplicate()) return;
      }
      if (!mounted) return;
      if (!widget.isEditMode && _duplicate != null) {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Найден водитель с похожим именем'),
            content: Text(
              '${_duplicate!.name}\n${_duplicate!.isActive ? 'Активен' : 'Неактивен'}\nЭто может быть другой человек. Можно создать нового водителя.',
            ),
            actions: [
              AppSecondaryButton(
                onPressed: () => Navigator.pop(context),
                text: 'Отмена',
              ),
              if (!_duplicate!.isActive)
                AppSecondaryButton(
                  onPressed: () => Navigator.pop(context, 'activate'),
                  text: 'Активировать',
                ),
              AppPrimaryButton(
                onPressed: () => Navigator.pop(context, 'create'),
                text: 'Создать нового',
              ),
            ],
          ),
        );
        if (!mounted || action == null) return;
        if (action == 'activate') {
          await _confirmAndActivate(_duplicate!);
          return;
        }
      }
      final name = _nameController.text.trim();
      final success = widget.isEditMode
          ? await provider.updateDriver(widget.driver!.id, name)
          : await provider.addDriver(name) != null;
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
      } else {
        setState(
          () => _error = 'Не удалось сохранить водителя. Проверьте соединение и повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndActivate(Driver driver) async {
    final provider = context.read<RouteConstructorProvider>();
    final confirmed = await showDriverActivationDialog(context, driver);
    if (!confirmed || !mounted) return;
    final success = await provider.activateAndSelectDriver(driver);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(
        () => _error = 'Не удалось активировать водителя. Повторите попытку.',
      );
    }
  }

  Future<void> _deactivate() async {
    if (_busy) return;
    final provider = context.read<RouteConstructorProvider>();
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Деактивировать водителя?',
      content:
          '«${widget.driver!.name}» станет недоступен для новых маршрутов. Запись и история сохранятся. Водителя можно активировать снова.',
      confirmText: 'Деактивировать',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final success = await provider.deactivateDriver(widget.driver!.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = 'Не удалось деактивировать водителя. Повторите попытку.';
      });
    }
  }

  @override
  void dispose() {
    _duplicateCheck.dispose();
    _checkVersion++;
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: BaseFormDialog(
      title: widget.isEditMode
          ? 'Редактирование водителя'
          : 'Добавление водителя',
      submitButtonText: widget.isEditMode
          ? (_changes.isEmpty ? 'ОК' : 'Сохранить')
          : 'Добавить',
      submitButtonWidth: 160,
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy,
      isLoading: _busy && !_checking,
      leadingAction: widget.isEditMode && widget.driver!.isActive
          ? AppIconButton(
              icon: Icons.archive_outlined,
              tooltip: 'Деактивировать водителя',
              destructive: true,
              onPressed: _busy ? null : _deactivate,
            )
          : null,
      children: [
        DuplicateCheckStatusWidget(
          idleText: !_needsDuplicateCheck
              ? 'Поля проверки не изменены'
              : _validDuplicateInput
              ? 'Ожидание завершения ввода…'
              : 'Для проверки заполните ФИО',
          isChecking: _checking,
          isChecked: _checkedName != null,
          hasDuplicate: _duplicate != null,
          warningText: _duplicate != null
              ? 'Найден водитель с похожим именем: ${_duplicate!.name} — ${_duplicate!.isActive ? 'Активен' : 'Неактивен'}'
              : '',
          expandedChild: _duplicate != null && _duplicate!.isActive
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
                                  .selectExistingDriver(_duplicate!);
                              Navigator.of(context).pop();
                            },
                    ),
                    AppSecondaryButton(
                      text: 'Открыть существующего водителя',
                      onPressed: _busy || widget.onOpenDriver == null
                          ? null
                          : () => widget.onOpenDriver!(_duplicate!),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          enabled: !_busy,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'ФИО водителя *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
            hintText: 'Иванов Иван Иванович',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Введите ФИО'
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
