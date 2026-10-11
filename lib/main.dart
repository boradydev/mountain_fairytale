import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/scaffold_messenger_key.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/services/secure_token_storage.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/delivery_route/services/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/features/delivery_route/services/windows_route_print_service.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_repo.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_demo_data.dart';
import 'package:mountain_fairytale/features/auth/data/auth_repo.dart';
import 'package:mountain_fairytale/features/auth/data/auth_api_data_source.dart';
import 'package:mountain_fairytale/features/cars/data/cars_repo.dart';
import 'package:mountain_fairytale/features/cars/data/cars_demo_data.dart';
import 'package:mountain_fairytale/features/clients/data/clients_repo.dart';
import 'package:mountain_fairytale/features/clients/data/clients_demo_data.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_repo.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_demo_data.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_repo.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_demo_data.dart';
import 'package:mountain_fairytale/infra/repos/drivers/repo.dart';
import 'package:mountain_fairytale/infra/repos/drivers/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/repo.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/pickup/repo.dart';
import 'package:mountain_fairytale/infra/repos/pickup/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/products/repo.dart';
import 'package:mountain_fairytale/infra/repos/products/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_clients/repo.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_clients/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_commissions/repo.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_commissions/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/repo.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/sources/demo_data.dart';
import 'package:mountain_fairytale/core/window_settings_service.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/presentation/providers/locale_provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/sales_representative_clients/ui/sales_representative_clients_provider.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/ui/sales_representative_commission_provider.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_representative_provider.dart';
import 'package:mountain_fairytale/presentation/providers/theme_provider.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days/dashboard.dart';
import 'package:mountain_fairytale/features/products/product_abcs.dart';
import 'package:mountain_fairytale/presentation/screens/login/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  double width = prefs.getDouble('window_width') ?? 1200;
  double height = prefs.getDouble('window_height') ?? 600;
  double? posX = prefs.getDouble('window_x');
  double? posY = prefs.getDouble('window_y');

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WindowOptions windowOptions = WindowOptions(
      size: Size(width, height),
      minimumSize: Size(1200, 600),
      center: posX == null,
      title: "Mountain Fairytale",
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (posX != null && posY != null) {
        await windowManager.setPosition(Offset(posX, posY));
      }
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(WindowSettingsService());
  }
  // ===========================================================================
  // 1. ИНИЦИАЛИЗАЦИЯ АТОМАРНЫХ ДАННЫХ (DATA SOURCES)
  // Каждый источник независим, хранит свой кэш и имитирует сетевые запросы
  // ===========================================================================
  final driverDataSource = DemoDriverDataSource();
  final carDataSource = DemoCarDataSource();
  final productDataSource = DemoProductDataSource();
  final deliveryDayDataSource = DemoDeliveryDataSource();
  final routeDataSource = DemoDeliveryRouteDataSource(
    deliveryDayDataSource: deliveryDayDataSource,
  );
  final clientDataSource = DemoClientDataSource();
  final paymentMethodDataSource = DemoPaymentMethodDataSource();
  final salesRepDataSource = DemoSalesRepresentativeDataSource();
  final salesRepCommissionDataSource =
      DemoSalesRepresentativeCommissionDataSource();
  final pickupDataSource = DemoPickupDataSource();

  final auditLogDataSource = DemoAuditLogDataSource();

  final auditLogRepository = AuditLogRepositoryImpl(
    auditLogDataSource,
  );
  // ===========================================================================
  // 2. ИНИЦИАЛИЗАЦИЯ РЕПОЗИТОРИЕВ
  // Принимают сущности от UI, конвертируют в JSON-Map и общаются с Data Sources
  // ===========================================================================
  final driverRepository = DriverRepositoryImpl(driverDataSource);
  final carRepository = CarRepositoryImpl(carDataSource);
  final productRepository = ProductRepositoryImpl(productDataSource);
  final routeRepository = DeliveryRouteRepositoryImpl(routeDataSource);
  final clientRepository = ClientRepositoryImpl(clientDataSource);
  final deliveryDayRepository = ApiDeliveryRepository(deliveryDayDataSource);
  final salesRepRepository = SalesRepresentativeRepositoryImpl(
    salesRepDataSource,
  );
  final paymentMethodRepository = PaymentMethodRepositoryImpl(
    paymentMethodDataSource,
  );
  final salesRepCommissionRepository =
      SalesRepresentativeCommissionRepositoryImpl(
        salesRepCommissionDataSource,
      );
  final pickupRepository = PickupRepositoryImpl(
    pickupDataSource,
  );

  // Инициализация модуля клиентов торгового представителя
  final salesRepClientDataSource = DemoSalesRepresentativeClientDataSource(
    clientDataSource: clientDataSource,
    salesRepRepo: salesRepRepository,
  );
  final salesRepClientRepository = SalesRepresentativeClientRepositoryImpl(
    salesRepClientDataSource,
  );

  // ===========================================================================
  // 3. ИНИЦИАЛИЗАЦИЯ СЕРВИСОВ
  // ===========================================================================
  final routePrintService = WindowsRoutePrintService(RouteSheetPdfBuilder());
  final httpTransport = HttpTransport(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    ),
  );

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
    userAgent: 'MountainFairytale/1.0 Windows',
  );

  // ===========================================================================
  // 4. ЗАПУСК ПРИЛОЖЕНИЯ И ВНЕДРЕНИЕ ЗАВИСИМОСТЕЙ (DI)
  // Передаем созданные синглтоны репозиториев в UI-провайдеры управления стейтом
  // ===========================================================================
  final sessionProviders = <SingleChildWidget>[
    // Репозитории (доступны через context.read<T>())
    Provider<ProductRepository>(
      create: (_) => productRepository,
    ),

    // Провайдер дашборда дней доставки
    ChangeNotifierProvider(
      create: (context) => DeliveryDaysProvider(deliveryDayRepository),
    ),

    // Провайдер списка клиентов (контроль засыпания, дубликаты)
    ChangeNotifierProvider(
      create: (context) => ClientsProvider(clientRepository),
    ),

    // Провайдер торговых представителей
    ChangeNotifierProvider(
      create: (_) => SalesRepresentativeProvider(salesRepRepository),
    ),

    // Провайдер деталей клиентов торгового представителя
    ChangeNotifierProvider(
      create: (context) =>
          SalesRepresentativeClientsProvider(salesRepClientRepository),
    ),

    // Обновленный провайдер конструктора маршрутов со строго изолированными репозиториями
    ChangeNotifierProvider(
      create: (context) => RouteConstructorProvider(
        carRepo: carRepository,
        driverRepo: driverRepository,
        productRepo: productRepository,
        routeRepo: routeRepository,
        paymentMethodRepo: paymentMethodRepository,
        clientRepo: clientRepository,
        printService: routePrintService,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => SalesRepresentativeCommissionProvider(
        salesRepCommissionRepository,
      ),
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

  runApp(
    MultiProvider(
      providers: [
        // Системные настройки (Тема и Локализация)
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),

        Provider<ApiClient>.value(value: apiClient),
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
    ),
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
    final app = MaterialApp(
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

      home: const _AuthGate(),
    );
    if (!auth.isAuthenticated) return app;
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
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case AuthStatus.unauthenticated:
        return const LoginScreen();

      case AuthStatus.serverUnavailable:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    auth.error ?? 'Не удалось восстановить вход.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.restoreSession,
                    child: const Text('Повторить'),
                  ),
                  TextButton(
                    onPressed: auth.logout,
                    child: const Text('Выйти'),
                  ),
                ],
              ),
            ),
          ),
        );

      case AuthStatus.authenticated:
        return const DeliveryDaysScreen();
    }
  }
}
