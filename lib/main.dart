import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/data_sources/cars/demo_car_data_source.dart';
import 'package:mountain_fairytale/infra/data_sources/clients/demo_data_source.dart';
import 'package:mountain_fairytale/infra/data_sources/delivery_day/demo_data_source.dart';
import 'package:mountain_fairytale/infra/data_sources/delivery_route/demo_delivery_route_data_source.dart';
import 'package:mountain_fairytale/infra/data_sources/drivers/demo_driver_data_source.dart';
import 'package:mountain_fairytale/infra/data_sources/products/demo_product_data_source.dart';
import 'package:mountain_fairytale/infra/repos/cars/repo.dart';
import 'package:mountain_fairytale/infra/repos/clients/repo.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/repo.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/repo.dart';
import 'package:mountain_fairytale/infra/repos/drivers/repo.dart';
import 'package:mountain_fairytale/infra/repos/products/repo.dart';
import 'package:mountain_fairytale/infra/window_settings_service.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/providers/delivery_days_provider.dart';
import 'package:mountain_fairytale/presentation/providers/locale_provider.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/providers/theme_provider.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days_screen/dashboard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  double width = prefs.getDouble('window_width') ?? 1000;
  double height = prefs.getDouble('window_height') ?? 600;
  double? posX = prefs.getDouble('window_x');
  double? posY = prefs.getDouble('window_y');

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WindowOptions windowOptions = WindowOptions(
      size: Size(width, height),
      minimumSize: Size(1000, 630),
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
  final routeDataSource = DemoDeliveryRouteDataSource();
  final clientDataSource = DemoClientDataSource();
  final deliveryDayDataSource = DemoDeliveryDataSource();

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

  // ===========================================================================
  // 3. ЗАПУСК ПРИЛОЖЕНИЯ И ВНЕДРЕНИЕ ЗАВИСИМОСТЕЙ (DI)
  // Передаем созданные синглтоны репозиториев в UI-провайдеры управления стейтом
  // ===========================================================================
  runApp(
    MultiProvider(
      providers: [
        // Системные настройки (Тема и Локализация)
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),

        // Провайдер дашборда дней доставки
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
          ),
        ),
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

      home: const DeliveryDaysScreen(),
    );
  }
}
