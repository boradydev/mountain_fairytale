import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/app/app_shell.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/data/current_employee_model.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/employees_abcs.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/data/sales_representative_commission_model.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/sales_representative_commission_abcs.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/ui/sales_representative_commission_provider.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';
import 'package:mountain_fairytale/shared/widgets/locate_toggle_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fakes.dart';

class _ClientsRepository implements ClientRepository {
  int calls = 0;

  @override
  Future<List<Client>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  }) async {
    calls++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeliveryRepository implements DeliveryDayRepository {
  int calls = 0;

  @override
  Future<DeliveryDaysPage> getDeliveryDays({
    required int offset,
    required int limit,
  }) async {
    calls++;
    return const DeliveryDaysPage(days: [], total: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuditRepository implements AuditLogRepository {
  final searches = <String?>[];

  @override
  Future<List<AuditEvent>> getAuditEvents({
    String? search,
    required int offset,
    required int limit,
  }) async {
    searches.add(search);
    return [];
  }
}

class _CommissionRepository implements SalesRepresentativeCommissionRepository {
  int calls = 0;

  @override
  Future<SalesRepresentativeCommissionReport>
  getSalesRepresentativeCommissions({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    calls++;
    return const SalesRepresentativeCommissionReport(
      commissions: [],
      totalCommissionAmount: 0,
    );
  }
}

class _EmployeeRepository implements EmployeeRepository {
  int calls = 0;

  @override
  Future<List<Employee>> getEmployees({bool includeDeactivated = false}) async {
    calls++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final isAdmin in [false, true]) {
    testWidgets(
      'loads tabs on demand and retains client mode, search, month; admin=$isAdmin',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final authRepo = FakeAuthRepository();
        if (isAdmin) {
          authRepo.onGetMe = (_) async => CurrentEmployeeModel(
            employeeId: employee.employeeId,
            username: employee.username,
            role: 'admin',
          );
        }
        final service = AuthServiceImpl(
          repository: authRepo,
          tokenStorage: MemoryTokenStorage(),
        );
        final auth = AuthProvider(authService: service);
        await auth.login(username: 'manager', password: '');
        final clientRepo = _ClientsRepository();
        final clients = ClientsProvider(clientRepo);
        final dayRepo = _DeliveryRepository();
        final days = DeliveryDaysProvider(dayRepo);
        final auditRepo = _AuditRepository();
        final audit = AuditLogProvider(auditRepo);
        final commissionRepo = _CommissionRepository();
        final commissions = SalesRepresentativeCommissionProvider(
          commissionRepo,
        );
        final theme = ThemeProvider(prefs);
        final employeeRepo = _EmployeeRepository();
        final employees = EmployeesProvider(employeeRepo);
        addTearDown(() {
          auth.dispose();
          service.dispose();
          clients.dispose();
          days.dispose();
          audit.dispose();
          commissions.dispose();
          theme.dispose();
          employees.dispose();
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: clients),
              ChangeNotifierProvider.value(value: days),
              ChangeNotifierProvider.value(value: audit),
              ChangeNotifierProvider.value(value: commissions),
              ChangeNotifierProvider.value(value: theme),
              if (isAdmin) ChangeNotifierProvider.value(value: employees),
            ],
            child: Builder(
              builder: (context) => MaterialApp(
                theme: theme.lightTheme,
                darkTheme: theme.darkTheme,
                themeMode: context.watch<ThemeProvider>().themeMode,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('ru'),
                home: const AppShell(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(clientRepo.calls, 1);
        expect(dayRepo.calls, 1);
        expect(auditRepo.searches, isEmpty);
        expect(commissionRepo.calls, 0);
        expect(find.byType(LocaleToggleButton), findsNothing);
        expect(
          find.text('Сотрудники'),
          isAdmin ? findsOneWidget : findsNothing,
        );
        expect(employeeRepo.calls, 0);

        await tester.tap(find.text('Обзвон клиентов'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Нет клиентов для обзвона.\nСейчас нет засыпающих клиентов без отложенного контакта.',
          ),
          findsOneWidget,
        );
        // Both modes remain available when the call queue is empty.
        expect(find.text('База клиентов'), findsOneWidget);
        expect(find.text('Добавить клиента'), findsNothing);

        if (isAdmin) {
          await tester.tap(find.text('Сотрудники'));
          await tester.pumpAndSettle();
          expect(employeeRepo.calls, 1);
          expect(find.text('Сотрудники ещё не добавлены.'), findsOneWidget);
          expect(find.byType(AppBar), findsOneWidget);
        }

        await tester.tap(find.text('Журнал событий'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'доставка');
        await tester.pumpAndSettle();
        expect(auditRepo.searches, [null, 'доставка']);

        await tester.tap(find.text('Вознаграждения'));
        await tester.pumpAndSettle();
        expect(commissionRepo.calls, 1);
        await tester.tap(find.text('Выбрать месяц'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Февраль'));
        await tester.tap(find.text('Выбрать'));
        await tester.pumpAndSettle();
        expect(commissions.dateFrom.month, 2);
        await tester.tap(find.text('Обновить'));
        await tester.pumpAndSettle();
        expect(commissionRepo.calls, 3);

        await tester.tap(find.byTooltip('Тёмная тема'));
        await tester.pumpAndSettle();
        expect(theme.isDarkMode, isTrue);
        expect(prefs.getBool('is_dark_mode'), isTrue);
        await tester.tap(find.byTooltip('manager'));
        await tester.pumpAndSettle();
        expect(find.text('Изменить пароль'), findsOneWidget);
        expect(find.text('Выйти'), findsOneWidget);
        expect(
          find.widgetWithText(PopupMenuItem<String>, 'Сотрудники'),
          findsNothing,
        );
        await tester.tapAt(const Offset(20, 200));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Журнал событий'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'доставка',
        );
        expect(auditRepo.searches.length, 2);
        await tester.tap(find.text('Дашборд'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SegmentedButton<ClientListMode>>(
                find.byType(SegmentedButton<ClientListMode>),
              )
              .selected,
          {ClientListMode.followUp},
        );
        await tester.tap(find.text('База клиентов'));
        await tester.pumpAndSettle();
        expect(find.text('Добавить клиента'), findsOneWidget);
        expect(clientRepo.calls, 1);
        expect(dayRepo.calls, 1);
        await tester.tap(find.text('Вознаграждения'));
        await tester.pumpAndSettle();
        expect(
          find.text('Февраль ${commissions.dateFrom.year}'),
          findsOneWidget,
        );
        expect(commissionRepo.calls, 3);
        if (isAdmin) {
          await tester.tap(find.text('Сотрудники'));
          await tester.pumpAndSettle();
          expect(employeeRepo.calls, 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
