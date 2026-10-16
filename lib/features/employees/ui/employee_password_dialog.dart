import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';

class EmployeePasswordDialog extends StatefulWidget {
  final Employee employee;
  final EmployeesProvider provider;

  const EmployeePasswordDialog({
    super.key,
    required this.employee,
    required this.provider,
  });

  @override
  State<EmployeePasswordDialog> createState() => _EmployeePasswordDialogState();
}

class _EmployeePasswordDialogState extends State<EmployeePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.provider.clearError();
    final success = await widget.provider.changePassword(
      widget.employee.id,
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = widget.provider.errorMessage ?? 'Не удалось изменить пароль.';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: BaseFormDialog(
      title: 'Изменение пароля',
      submitButtonText: 'Сохранить',
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy,
      isLoading: _busy,
      children: [
        Text('Сотрудник: ${widget.employee.username}'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          enabled: !_busy,
          obscureText: !_showPassword,
          maxLength: 50,
          decoration: InputDecoration(
            labelText: 'Новый пароль',
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmationController,
          enabled: !_busy,
          obscureText: !_showPassword,
          maxLength: 50,
          decoration: const InputDecoration(
            labelText: 'Повторите пароль',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (value) =>
              value == _passwordController.text ? null : 'Пароли не совпадают',
          onFieldSubmitted: (_) => _save(),
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
