import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/ui/employee_dialog.dart';
import 'package:mountain_fairytale/features/employees/ui/employee_password_dialog.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _includeDeactivated = false;
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EmployeesProvider>().loadEmployees();
    });
  }

  Employee? _selected(List<Employee> visibleEmployees) {
    Employee? firstActive;
    for (final employee in visibleEmployees) {
      if (employee.id == _selectedEmployeeId) return employee;
      if (firstActive == null && employee.isActive) firstActive = employee;
    }
    return firstActive ??
        (visibleEmployees.isEmpty ? null : visibleEmployees.first);
  }

  Future<void> _openEditor({Employee? employee}) async {
    final provider = context.read<EmployeesProvider>();
    provider.clearError();
    Employee? employeeToOpen;
    final saved = await showDialog<Employee>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EmployeeDialog(
        provider: provider,
        employee: employee,
        onOpenEmployee: (existing) {
          employeeToOpen = existing;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    if (!mounted) return;
    if (employeeToOpen != null) {
      await _openEditor(employee: employeeToOpen);
      return;
    }
    if (saved == null) return;
    setState(() => _selectedEmployeeId = saved.id);
  }

  Future<void> _changePassword(Employee employee) async {
    final provider = context.read<EmployeesProvider>();
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmployeePasswordDialog(
        employee: employee,
        provider: provider,
      ),
    );
    if (!mounted || changed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пароль сотрудника изменён.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeesProvider>();
    final allEmployees = provider.employees;
    final employees = _includeDeactivated
        ? allEmployees
        : allEmployees.where((employee) => employee.isActive).toList();
    final selected = _selected(employees);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: provider.isLoading && allEmployees.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.errorMessage != null && allEmployees.isEmpty
              ? _LoadError(
                  message: provider.errorMessage!,
                  onRetry: provider.loadEmployees,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDropdown<Employee>(
                      key: ValueKey(selected?.id),
                      label: 'Сотрудник',
                      items: employees,
                      value: selected,
                      hint: employees.isEmpty
                          ? 'Нет сотрудников'
                          : 'Выберите сотрудника',
                      prefixIcon: Icons.people_outline,
                      itemLabelBuilder: (employee) => employee.username,
                      itemBuilder: (employee) => Row(
                        children: [
                          Expanded(child: Text(employee.username)),
                          if (!employee.isActive)
                            const Text(
                              'Неактивен',
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      onChanged: (employee) => setState(
                        () => _selectedEmployeeId = employee?.id,
                      ),
                      enabled: !provider.isLoading,
                      showAdd: true,
                      editBeforeAdd: true,
                      onAdd: () => _openEditor(),
                      showEdit: true,
                      onEdit: selected == null
                          ? null
                          : () => _openEditor(employee: selected),
                      showInactiveToggle: true,
                      includeInactive: _includeDeactivated,
                      onIncludeInactiveChanged: (value) => setState(() {
                        _includeDeactivated = value;
                        if (!value && selected != null && !selected.isActive) {
                          _selectedEmployeeId = null;
                        }
                      }),
                    ),
                    if (provider.isLoading && allEmployees.isNotEmpty)
                      const LinearProgressIndicator(),
                    if (provider.errorMessage != null &&
                        allEmployees.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (selected == null)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Сотрудники ещё не добавлены.'),
                        ),
                      )
                    else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.username,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Комиссия: ${_formatPercent(selected.commissionPercent)}%',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Статус: ${selected.isActive ? 'Активен' : 'Неактивен'}',
                              ),
                              if (selected.isAdmin) ...[
                                const SizedBox(height: 4),
                                const Text('Роль: администратор'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppSecondaryButton(
                          text: 'Изменить пароль',
                          onPressed: () => _changePassword(selected),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  String _formatPercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      const SizedBox(height: 12),
      AppPrimaryButton(text: 'Повторить', onPressed: onRetry),
    ],
  );
}
