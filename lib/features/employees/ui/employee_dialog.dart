import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class EmployeeDialog extends StatefulWidget {
  final EmployeesProvider provider;
  final Employee? employee;
  final ValueChanged<Employee>? onOpenEmployee;

  const EmployeeDialog({
    super.key,
    required this.provider,
    this.employee,
    this.onOpenEmployee,
  });

  @override
  State<EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _commissionController;
  bool _busy = false;
  bool _showPassword = false;
  String? _usernameError;
  String? _error;
  final _usernameFocusNode = FocusNode();
  Employee? _duplicate;
  String? _checkedUsername;
  bool _checking = false;
  int _checkVersion = 0;

  bool get _isEditMode => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.employee?.username ?? '',
    )..addListener(_onUsernameChanged);
    _passwordController = TextEditingController();
    _commissionController = TextEditingController(
      text: widget.employee?.commissionPercent.toString() ?? '',
    );
    _usernameFocusNode.addListener(_onUsernameFocusChanged);
  }

  void _onUsernameFocusChanged() {
    if (!_usernameFocusNode.hasFocus && !_busy) _checkDuplicate();
  }

  Future<void> _checkDuplicate() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length > 50) return;
    final version = ++_checkVersion;
    setState(() {
      _checking = true;
      _checkedUsername = null;
      _duplicate = null;
    });
    try {
      final duplicate = await widget.provider.checkDuplicate(username);
      if (!mounted || version != _checkVersion) return;
      setState(() {
        _checking = false;
        _checkedUsername = username;
        _duplicate = duplicate?.id == widget.employee?.id ? null : duplicate;
      });
    } catch (_) {
      if (!mounted || version != _checkVersion) return;
      setState(() {
        _checking = false;
        _error = 'Не удалось проверить логин. Повторите попытку.';
      });
    }
  }

  Future<void> _activateDuplicate(Employee employee) async {
    if (_busy) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Активировать сотрудника?',
      content:
          'Восстановить доступ для «${employee.username}»? Сохранятся его логин, комиссия и пароль.',
      confirmText: 'Активировать',
    );
    if (!mounted || !confirmed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.provider.updateEmployee(
      employee.id,
      const UpdateEmployeeRequest(isActive: true),
    );
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
    } else {
      setState(() {
        _busy = false;
        _error = widget.provider.errorMessage;
      });
    }
  }

  void _onUsernameChanged() {
    _checkVersion++;
    setState(() {
      _duplicate = null;
      _checkedUsername = null;
      _checking = false;
    });
    if (_usernameError != null || widget.provider.usernameError != null) {
      setState(() => _usernameError = null);
      widget.provider.clearUsernameError();
    }
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final username = _usernameController.text.trim();
    final commissionPercent = double.parse(
      _commissionController.text.trim().replaceAll(',', '.'),
    );
    setState(() {
      _busy = true;
      _error = null;
      _usernameError = null;
    });
    widget.provider.clearError();
    try {
      if (_checkedUsername != username) await _checkDuplicate();
      if (!mounted) return;
      final Employee? saved;
      if (_isEditMode) {
        saved = await widget.provider.updateEmployee(
          widget.employee!.id,
          UpdateEmployeeRequest(
            username: username,
            commissionPercent: commissionPercent,
          ),
        );
      } else {
        saved = await widget.provider.createEmployee(
          CreateEmployeeRequest(
            username: username,
            password: _passwordController.text,
            commissionPercent: commissionPercent,
          ),
        );
      }
      if (!mounted) return;
      if (saved != null) {
        Navigator.of(context).pop(saved);
      } else {
        setState(() {
          _usernameError = widget.provider.usernameError;
          _error = _usernameError == null
              ? widget.provider.errorMessage ??
                    'Не удалось сохранить сотрудника.'
              : null;
        });
        if (_usernameError != null) await _checkDuplicate();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeActive(bool isActive) async {
    if (_busy) return;
    final employee = widget.employee!;
    if (!isActive) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Деактивировать сотрудника?',
        content:
            'Учётная запись «${employee.username}» станет недоступна для входа. Данные сотрудника сохранятся, и его можно будет активировать снова.',
        confirmText: 'Деактивировать',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.provider.updateEmployee(
      employee.id,
      UpdateEmployeeRequest(isActive: isActive),
    );
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
    } else {
      setState(() {
        _error =
            widget.provider.errorMessage ??
            'Не удалось изменить статус сотрудника.';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _checkVersion++;
    _usernameFocusNode.removeListener(_onUsernameFocusChanged);
    _usernameFocusNode.dispose();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: BaseFormDialog(
      title: _isEditMode
          ? 'Редактирование сотрудника'
          : 'Добавление сотрудника',
      submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy,
      leadingAction: _isEditMode && !widget.employee!.isAdmin
          ? AppIconButton(
              icon: widget.employee!.isActive
                  ? Icons.archive_outlined
                  : Icons.check_circle_outline,
              tooltip: widget.employee!.isActive
                  ? 'Деактивировать сотрудника'
                  : 'Активировать сотрудника',
              destructive: widget.employee!.isActive,
              onPressed: _busy
                  ? null
                  : () => _changeActive(!widget.employee!.isActive),
            )
          : null,
      children: [
        if (_busy) const LinearProgressIndicator(),
        DuplicateCheckStatusWidget(
          isChecking: _checking,
          isChecked: _checkedUsername != null,
          hasDuplicate: _duplicate != null,
          warningText: _duplicate == null
              ? ''
              : 'Найден сотрудник: ${_duplicate!.username} — ${_duplicate!.isActive ? 'Активен' : 'Неактивен'}. Логин уже занят.',
          expandedChild: _duplicate == null
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPrimaryButton(
                      text: _duplicate!.isActive
                          ? 'Выбрать сотрудника'
                          : 'Активировать и выбрать',
                      onPressed: _busy
                          ? null
                          : () {
                              final employee = _duplicate!;
                              if (employee.isActive) {
                                Navigator.of(context).pop(employee);
                              } else {
                                _activateDuplicate(employee);
                              }
                            },
                    ),
                    AppSecondaryButton(
                      text: 'Открыть существующего сотрудника',
                      onPressed: _busy || widget.onOpenEmployee == null
                          ? null
                          : () => widget.onOpenEmployee!(_duplicate!),
                    ),
                  ],
                ),
        ),
        TextFormField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          forceErrorText: _usernameError ?? widget.provider.usernameError,
          enabled: !_busy,
          maxLength: 50,
          decoration: const InputDecoration(
            labelText: 'Логин *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
            errorMaxLines: 2,
          ),
          validator: (value) {
            final username = value?.trim() ?? '';
            if (username.isEmpty) return 'Введите логин';
            if (username.length > 50) return 'Не более 50 символов';
            return null;
          },
        ),
        if (!_isEditMode) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            enabled: !_busy,
            obscureText: !_showPassword,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'Пароль',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: 'Можно оставить пустым',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Скрыть пароль' : 'Показать пароль',
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _commissionController,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Комиссия *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.percent),
            suffixText: '%',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final percent = double.tryParse(
              value?.trim().replaceAll(',', '.') ?? '',
            );
            if (percent == null || !percent.isFinite) {
              return 'Введите корректный процент';
            }
            if (percent < 0 || percent > 100) {
              return 'Процент должен быть от 0 до 100';
            }
            return null;
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );
}
