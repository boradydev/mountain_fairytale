import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/app/app_shell.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
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
  Future<List<DeliveryDay>> getDeliveryDays({
    required int offset,
    required int limit,
  }) async {
    calls++;
    return [];
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

void main() {
  testWidgets(
    'loads tabs on demand and retains filters, search, month and account actions',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authRepo = FakeAuthRepository();
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
      final commissions = SalesRepresentativeCommissionProvider(commissionRepo);
      final theme = ThemeProvider(prefs);
      addTearDown(() {
        auth.dispose();
        service.dispose();
        clients.dispose();
        days.dispose();
        audit.dispose();
        commissions.dispose();
        theme.dispose();
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
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              theme: theme.lightTheme,
              darkTheme: theme.darkTheme,
              themeMode: context.watch<ThemeProvider>().themeMode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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

      await tester.tap(find.text('Просроченные'));
      await tester.pumpAndSettle();
      expect(
        find.text('Все клиенты в порядке!\nПросроченных нет.'),
        findsOneWidget,
      );
      // The filter remains available so an empty result can be cleared.
      expect(find.byType(FilterChip), findsOneWidget);

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
      expect(find.text('Сотрудники'), findsNothing);
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
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isTrue,
      );
      await tester.tap(find.text('Просроченные'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить клиента'), findsOneWidget);
      expect(clientRepo.calls, 1);
      expect(dayRepo.calls, 1);
      await tester.tap(find.text('Вознаграждения'));
      await tester.pumpAndSettle();
      expect(find.text('Февраль ${commissions.dateFrom.year}'), findsOneWidget);
      expect(commissionRepo.calls, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
