import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/features/commissions/data/commissions_repo.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';

import 'dart:async';
import 'dart:io';

import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_provider.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_screen.dart';

import 'package:mountain_fairytale/features/app_updates/update_service.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/directories/ui/directories_provider.dart';
import 'package:mountain_fairytale/features/dashboard/data/dashboard_updates_repo.dart';
import 'package:mountain_fairytale/core/utils/scaffold_messenger_key.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/services/secure_token_storage.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/delivery_route/services/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/features/delivery_route/services/windows_route_print_service.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_repo.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_api_data_source.dart';
import 'package:mountain_fairytale/features/auth/data/auth_repo.dart';
import 'package:mountain_fairytale/features/auth/data/auth_api_data_source.dart';
import 'package:mountain_fairytale/features/cars/data/cars_repo.dart';
import 'package:mountain_fairytale/features/cars/data/cars_api_data_source.dart';
import 'package:mountain_fairytale/features/clients/data/clients_repo.dart';
import 'package:mountain_fairytale/features/clients/data/clients_api_data_source.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_repo.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_api_data_source.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_repo.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_api_data_source.dart';
import 'package:mountain_fairytale/features/drivers/data/drivers_repo.dart';
import 'package:mountain_fairytale/features/drivers/data/drivers_api_data_source.dart';
import 'package:mountain_fairytale/features/employees/data/employees_api_data_source.dart';
import 'package:mountain_fairytale/features/employees/data/employees_repo.dart';
import 'package:mountain_fairytale/features/employees/employees_abcs.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_repo.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_api_data_source.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_repo.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_api_data_source.dart';
import 'package:mountain_fairytale/features/products/data/products_repo.dart';
import 'package:mountain_fairytale/features/products/data/products_api_data_source.dart';
import 'package:mountain_fairytale/core/window_settings_service.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/shared/providers/locale_provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';
import 'package:mountain_fairytale/app/app_shell.dart';
import 'package:mountain_fairytale/app/server_application_scope.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';
import 'package:mountain_fairytale/features/auth/ui/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:mountain_fairytale/core/monitoring/monitoring_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final storedSize = Size(
    prefs.getDouble('window_width') ??
        WindowSettingsService.defaultWindowSize.width,
    prefs.getDouble('window_height') ??
        WindowSettingsService.defaultWindowSize.height,
  );
  final windowSize = WindowSettingsService.isValidSize(storedSize)
      ? storedSize
      : WindowSettingsService.defaultWindowSize;
  final posX = prefs.getDouble('window_x');
  final posY = prefs.getDouble('window_y');

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final storedPosition = posX != null && posY != null
        ? Offset(posX, posY)
        : null;
    final restorePosition =
        storedPosition != null &&
        await WindowSettingsService.isPositionVisible(
          storedPosition,
          windowSize,
        );

    final windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: WindowSettingsService.minimumWindowSize,
      center: !restorePosition,
      title: "Mountain Fairytale",
    );
    final restoreMaximized =
        prefs.getBool(WindowSettingsService.maximizedKey) ?? false;

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (restorePosition) {
        await windowManager.setPosition(storedPosition);
      }
      if (restoreMaximized) await windowManager.maximize();
      windowManager.addListener(WindowSettingsService(prefs));
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final serverSettings = ServerSettingsProvider(
    ServerSettingsRepository(
      prefs,
      defaultUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8000',
      ),
    ),
  );
  final monitoring = MonitoringService();
  serverSettings.addListener(() => monitoring.changeServer(serverSettings.url));
  monitoring.changeServer(serverSettings.url);
  runApp(
    AnimatedBuilder(
      animation: serverSettings,
      builder: (_, _) => ServerApplicationScope(
        key: ValueKey(serverSettings.url),
        createApplication: () => _configuredApplication(prefs, serverSettings),
      ),
    ),
  );
}

Widget _configuredApplication(
  SharedPreferences prefs,
  ServerSettingsProvider serverSettings,
) {
  final routePrintService = WindowsRoutePrintService(RouteSheetPdfBuilder());
  final httpTransport = HttpTransport(baseUrl: serverSettings.url);

  final tokenStorage = SecureTokenStorage();

  final authDataSource = AuthApiDataSource(
    transport: httpTransport,
  );

  final authRepository = AuthRepositoryImpl(
    dataSource: authDataSource,
  );

  final authService = AuthServiceImpl(
    repository: authRepository,
    tokenStorage: tokenStorage,
  );

  final apiClient = ApiClient(
    transport: httpTransport,
    authService: authService,
  );

  final routeRepository = DeliveryRouteRepositoryImpl(
    ApiDeliveryRouteDataSource(apiClient),
  );
  final pickupRepository = PickupRepositoryImpl(ApiPickupDataSource(apiClient));
  final deliveryDayRepository = ApiDeliveryRepository(
    ApiDeliveryDaysDataSource(apiClient),
  );

  final clientRepository = ClientRepositoryImpl(ApiClientDataSource(apiClient));

  final driverRepository = DriverRepositoryImpl(ApiDriverDataSource(apiClient));
  final employeeRepository = EmployeeRepositoryImpl(
    ApiEmployeeDataSource(apiClient),
  );
  final carRepository = CarRepositoryImpl(ApiCarDataSource(apiClient));
  final paymentMethodRepository = PaymentMethodRepositoryImpl(
    ApiPaymentMethodDataSource(apiClient),
  );
  final productDataSource = ApiProductDataSource(apiClient);
  final productRepository = ProductRepositoryImpl(productDataSource);
  final auditLogRepository = AuditLogRepositoryImpl(
    ApiAuditLogDataSource(apiClient),
  );

  // ===========================================================================
  // 4. ЗАПУСК ПРИЛОЖЕНИЯ И ВНЕДРЕНИЕ ЗАВИСИМОСТЕЙ (DI)
  // Передаем созданные синглтоны репозиториев в UI-провайдеры управления стейтом
  // ===========================================================================
  final sessionProviders = <SingleChildWidget>[
    ChangeNotifierProvider(
      create: (_) => DirectoriesProvider(
        products: productRepository,
        drivers: driverRepository,
        cars: carRepository,
        paymentMethods: paymentMethodRepository,
        representatives: SalesRepresentativeApiRepository(apiClient),
        createEditor: () => RouteConstructorProvider(
          carRepo: carRepository,
          driverRepo: driverRepository,
          productRepo: productRepository,
          routeRepo: routeRepository,
          paymentMethodRepo: paymentMethodRepository,
          clientRepo: clientRepository,
          printService: routePrintService,
        ),
      ),
    ),
    Provider<DeliveryRouteRepository>.value(value: routeRepository),
    Provider<PickupRepository>.value(value: pickupRepository),
    Provider<SalesRepresentativeApiRepository>(
      create: (_) => SalesRepresentativeApiRepository(apiClient),
    ),
    Provider<EmployeeRepository>.value(value: employeeRepository),
    ChangeNotifierProvider(
      create: (_) => EmployeesProvider(
        employeeRepository,
        onEmployeeUpdated: (employee) => authService.updateCurrentUsername(
          employeeId: employee.id,
          username: employee.username,
        ),
      ),
    ),

    // Репозитории (доступны через context.read<T>())
    Provider<ProductRepository>(
      create: (_) => productRepository,
    ),

    // Провайдер дашборда дней доставки
    Provider<DashboardUpdatesRepository>(
      create: (context) =>
          DashboardUpdatesRepository(context.read<ApiClient>()),
    ),
    ChangeNotifierProvider(
      create: (context) => DeliveryDaysProvider(deliveryDayRepository),
    ),

    // Провайдер списка клиентов (контроль засыпания, дубликаты)
    ChangeNotifierProvider(
      create: (context) => ClientsProvider(clientRepository),
    ),

    // Обновленный провайдер конструктора маршрутов со строго изолированными репозиториями
    ChangeNotifierProvider(
      create: (context) => RouteConstructorProvider(
        carRepo: carRepository,
        driverRepo: driverRepository,
        productRepo: productRepository,
        routeRepo: routeRepository,
        locationRepository: LocationRepository(apiClient),
        paymentMethodRepo: paymentMethodRepository,
        clientRepo: clientRepository,
        printService: routePrintService,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => CommissionsProvider(ApiCommissionsRepository(apiClient)),
    ),
    ChangeNotifierProvider(
      create: (context) => PickupConstructorProvider(
        pickupRepo: pickupRepository,
        productRepo: productRepository,
        paymentMethodRepo: paymentMethodRepository,
        clientRepo: clientRepository,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => AuditLogProvider(
        auditLogRepository,
      ),
    ),
  ];

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ServerSettingsProvider>.value(
        value: serverSettings,
      ),
      Provider<HttpTransport>(
        lazy: false,
        create: (_) => httpTransport,
        dispose: (_, transport) => transport.close(),
      ),
      ChangeNotifierProvider(
        lazy: false,
        create: (_) {
          final compatibility = AppCompatibilityProvider(
            transport: httpTransport,
          );
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => compatibility.check(),
          );
          return compatibility;
        },
      ),
      ChangeNotifierProvider<AuthServiceImpl>(
        lazy: false,
        create: (_) => authService,
      ),
      ChangeNotifierProvider(
        lazy: false,
        create: (_) {
          final updates = UpdateProvider(UpdateService());
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => updates.start(),
          );
          return updates;
        },
      ),
      // Системные настройки (Тема и Локализация)
      ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),

      Provider<ApiClient>.value(value: apiClient),
      Provider<LocationRepository>.value(
        value: LocationRepository(apiClient),
      ),
      ListenableProvider<AuthService>.value(
        value: authService,
      ),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          authService: authService,
        ),
      ),
    ],
    child: MyApp(sessionProviders: sessionProviders),
  );
}

class MyApp extends StatelessWidget {
  final List<SingleChildWidget> sessionProviders;

  const MyApp({super.key, required this.sessionProviders});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    final auth = context.watch<AuthProvider>();
    final compatibility = context.watch<AppCompatibilityProvider>();
    final app = MaterialApp(
      // Replacing the Navigator discards open forms and modal routes on refusal.
      key: ValueKey(compatibility.workEpoch),
      onGenerateTitle: (context) {
        final title = AppLocalizations.of(context)!.appTitle;
        windowManager.setTitle(title);
        return title;
      },

      debugShowCheckedModeBanner: false,

      locale: localeProvider.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      themeMode: themeProvider.themeMode,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,

      scaffoldMessengerKey: scaffoldMessengerKey,

      home: switch (compatibility.status) {
        CompatibilityStatus.updateRequired => const AppCompatibilityScreen(),
        CompatibilityStatus.compatible => const _AuthGate(),
        _ => LoginScreen(
          connectionReady: false,
          connecting:
              compatibility.checking ||
              compatibility.status == CompatibilityStatus.checking,
          connectionError: compatibility.error,
          onRetryConnection: compatibility.check,
        ),
      },
    );
    if (!auth.isAuthenticated || !compatibility.compatible) return app;
    return MultiProvider(
      key: ValueKey(auth.sessionVersion),
      providers: sessionProviders,
      child: app,
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.initializing) auth.restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.initializing:
        return const LoginScreen(
          connectionReady: false,
          connecting: true,
        );

      case AuthStatus.unauthenticated:
        return const LoginScreen();

      case AuthStatus.serverUnavailable:
        return LoginScreen(
          key: const ValueKey('session-unavailable'),
          connectionError: auth.error ?? 'Не удалось восстановить вход.',
          onRetryConnection: auth.restoreSession,
        );

      case AuthStatus.authenticated:
        return const AppShell();
    }
  }
}
