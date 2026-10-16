import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/ui/employee_dialog.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:mountain_fairytale/shared/widgets/list_section_header.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _includeDeactivated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EmployeesProvider>().loadEmployees();
    });
  }

  Future<void> _openEditor({Employee? employee}) async {
    final provider = context.read<EmployeesProvider>();
    provider.clearError();
    Employee? employeeToOpen;
    await showDialog<Employee>(
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeesProvider>();
    final allEmployees = provider.employees;
    final employees = _includeDeactivated
        ? allEmployees
        : allEmployees.where((employee) => employee.isActive).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListSectionHeader(
              title: 'Сотрудники',
              description: 'Добавление и редактирование сотрудников.',
              controls: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: LabeledCheckboxToggle(
                  label: 'Деактивированные',
                  value: _includeDeactivated,
                  onChanged: (value) =>
                      setState(() => _includeDeactivated = value),
                  tooltip: 'Показывать деактивированных сотрудников вместе с активными',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1),
            ),
            if (provider.isLoading && allEmployees.isNotEmpty)
              const LinearProgressIndicator(),
            if (provider.errorMessage != null && allEmployees.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  provider.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: provider.isLoading && allEmployees.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.errorMessage != null && allEmployees.isEmpty
                  ? Center(
                      child: _LoadError(
                        message: provider.errorMessage!,
                        onRetry: provider.loadEmployees,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: employees.isEmpty ? 2 : employees.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return AddActionButton(
                            label: 'Добавить сотрудника',
                            icon: Icons.person_add_alt_1_outlined,
                            onTap: () => _openEditor(),
                          );
                        }
                        if (employees.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              allEmployees.isEmpty
                                  ? 'Сотрудники ещё не добавлены.'
                                  : 'Нет активных сотрудников.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final employee = employees[index - 1];
                        return _EmployeeCard(
                          key: ValueKey(employee.id),
                          employee: employee,
                          onTap: () => _openEditor(employee: employee),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;

  const _EmployeeCard({super.key, required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = employee.commissionPercent;
    final formattedPercent = percent == null
        ? null
        : percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toString();

    return AppBaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(employee.username, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            employee.isActive ? 'Активен' : 'Деактивирован',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 8),
          Text(
            formattedPercent == null
                ? 'Без комиссии'
                : 'Комиссия: $formattedPercent%',
          ),
          if (employee.isAdmin) ...[
            const SizedBox(height: 4),
            const Text('Роль: администратор'),
          ],
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
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
    ),
  );
}
