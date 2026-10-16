import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/employees_abcs.dart';
import 'package:mountain_fairytale/features/employees/ui/employee_dialog.dart';
import 'package:mountain_fairytale/features/employees/ui/employee_password_dialog.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_screen.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:provider/provider.dart';

class _EmployeesRepository implements EmployeeRepository {
  bool? includeDeactivated;

  @override
  Future<List<Employee>> getEmployees({bool includeDeactivated = false}) async {
    this.includeDeactivated = includeDeactivated;
    return [
      Employee(
        id: 'active',
        username: 'manager',
        role: 'admin',
        commissionPercent: 5,
        isActive: true,
        createdAt: DateTime(2026),
      ),
      Employee(
        id: 'inactive',
        username: 'archived',
        role: 'employee',
        commissionPercent: 2.5,
        isActive: false,
        createdAt: DateTime(2026),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_EmployeesRepository> _openScreen(WidgetTester tester) async {
  final repository = _EmployeesRepository();
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => EmployeesProvider(repository),
      child: MaterialApp(
        theme: AppTheme.createTheme(Brightness.light),
        home: const Scaffold(body: EmployeesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('shows employee cards and toggles deactivated employees', (
    tester,
  ) async {
    final repository = await _openScreen(tester);
    expect(repository.includeDeactivated, isTrue);
    expect(find.byType(AppDropdown<Employee>), findsNothing);
    expect(find.byType(AddActionButton), findsOneWidget);
    expect(find.text('manager'), findsOneWidget);
    expect(find.text('Комиссия: 5%'), findsOneWidget);
    expect(find.text('Роль: администратор'), findsOneWidget);
    expect(find.text('archived'), findsNothing);

    await tester.tap(find.byType(LabeledCheckboxToggle));
    await tester.pumpAndSettle();
    expect(find.text('archived'), findsOneWidget);
    expect(find.text('Деактивирован'), findsOneWidget);
    expect(find.text('Комиссия: 2.5%'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppBaseCard, 'archived'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EmployeeDialog>(find.byType(EmployeeDialog)).employee?.id,
      'inactive',
    );
    expect(find.byTooltip('Активировать сотрудника'), findsOneWidget);
    await tester.ensureVisible(find.text('Отмена'));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LabeledCheckboxToggle));
    await tester.pumpAndSettle();
    expect(find.text('archived'), findsNothing);
  });

  testWidgets('opens creation, editing and the existing password dialog', (
    tester,
  ) async {
    await _openScreen(tester);
    await tester.tap(find.byType(AddActionButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EmployeeDialog>(find.byType(EmployeeDialog)).employee,
      isNull,
    );
    expect(find.text('Добавление сотрудника'), findsOneWidget);
    expect(find.text('Изменить пароль'), findsNothing);
    await tester.ensureVisible(find.text('Отмена'));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppBaseCard, 'manager'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EmployeeDialog>(find.byType(EmployeeDialog)).employee?.id,
      'active',
    );
    await tester.ensureVisible(find.text('Изменить пароль'));
    await tester.tap(find.text('Изменить пароль'));
    await tester.pumpAndSettle();
    expect(find.byType(EmployeePasswordDialog), findsOneWidget);
    expect(
      tester
          .widget<EmployeePasswordDialog>(find.byType(EmployeePasswordDialog))
          .employee
          .id,
      'active',
    );
    await tester.ensureVisible(find.text('Отмена').last);
    await tester.tap(find.text('Отмена').last);
    await tester.pumpAndSettle();
    expect(find.byType(EmployeePasswordDialog), findsNothing);
    expect(find.byType(EmployeeDialog), findsOneWidget);
  });
}
