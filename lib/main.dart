import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/scaffold_messenger_key.dart';
import 'package:mountain_fairytale/infra/auth/auth_service.dart';
import 'package:mountain_fairytale/infra/auth/auth_service_impl.dart';
import 'package:mountain_fairytale/infra/auth/secure_token_storage.dart';
import 'package:mountain_fairytale/infra/http/api_client.dart';
import 'package:mountain_fairytale/infra/http/http_transport.dart';
import 'package:mountain_fairytale/infra/printing/pdf/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/infra/printing/windows_route_print_service.dart';
import 'package:mountain_fairytale/infra/repos/auth/repo_impl.dart';
import 'package:mountain_fairytale/infra/repos/auth/sources/api_data_source.dart';
import 'package:mountain_fairytale/infra/repos/cars/repo.dart';
import 'package:mountain_fairytale/infra/repos/cars/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/clients/repo.dart';
import 'package:mountain_fairytale/infra/repos/clients/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/repo.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/repo.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/sources/demo_data.dart';
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
import 'package:mountain_fairytale/infra/window_settings_service.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/presentation/providers/auth_provider.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/providers/delivery_days_provider.dart';
import 'package:mountain_fairytale/presentation/providers/locale_provider.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/providers/sales_representative_clients_provider.dart';
import 'package:mountain_fairytale/presentation/providers/sales_representative_commission_provider.dart';
import 'package:mountain_fairytale/presentation/providers/sales_representative_provider.dart';
import 'package:mountain_fairytale/presentation/providers/theme_provider.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days/dashboard.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/product_contracts.dart';
import 'package:mountain_fairytale/presentation/screens/login/login_screen.dart';
import 'package:provider/provider.dart';
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
    baseUrl: 'http://localhost:8000',
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
  runApp(
    MultiProvider(
      providers: [
        // Системные настройки (Тема и Локализация)
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),

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
        Provider<AuthService>.value(
          value: authService,
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: authService,
          ),
        ),

        // Здесь потом:
        //
        // Provider<ClientRepository>(
        //   create: (_) => ClientRepositoryImpl(
        //     dataSource: ClientApiDataSource(
        //       apiClient: apiClient,
        //     ),
        //   ),
        // ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
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
      context.read<AuthProvider>().restoreSession();
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

      case AuthStatus.authenticated:
        return const DeliveryDaysScreen();
    }
  }
}
