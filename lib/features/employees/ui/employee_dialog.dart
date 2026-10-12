import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

class EmployeeDialog extends StatefulWidget {
  final EmployeesProvider provider;
  final Employee? employee;

  const EmployeeDialog({
    super.key,
    required this.provider,
    this.employee,
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
  }

  void _onUsernameChanged() {
    if (_usernameError != null || widget.provider.usernameError != null) {
      setState(() => _usernameError = null);
      widget.provider.clearUsernameError();
    }
    if (_error != null) setState(() => _error = null);
  }

  bool _usernameIsDuplicate(String username) => widget.provider.employees.any(
    (employee) =>
        employee.id != widget.employee?.id &&
        employee.username.trim() == username,
  );

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final username = _usernameController.text.trim();
    if (_usernameIsDuplicate(username)) {
      setState(() => _usernameError = 'Такой логин уже существует.');
      return;
    }

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
        TextFormField(
          controller: _usernameController,
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
