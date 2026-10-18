import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/dialog_card_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/data/auth_api_data_source.dart';
import 'package:mountain_fairytale/features/auth/data/auth_repo.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/cars/data/cars_api_data_source.dart';
import 'package:mountain_fairytale/features/cars/data/cars_repo.dart';
import 'package:mountain_fairytale/features/clients/data/clients_api_data_source.dart';
import 'package:mountain_fairytale/features/clients/data/clients_repo.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_api_data_source.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_repo.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_day_list.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_api_data_source.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_repo.dart';
import 'package:mountain_fairytale/features/delivery_route/services/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/drivers/data/drivers_api_data_source.dart';
import 'package:mountain_fairytale/features/drivers/data/drivers_repo.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_api_data_source.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_repo.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_api_data_source.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_repo.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/features/products/data/products_api_data_source.dart';
import 'package:mountain_fairytale/features/products/data/products_repo.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

import '../auth/auth_fakes.dart' show MemoryTokenStorage;

// This opt-in suite never resets the database or starts/restarts the server.
class _RealHttp extends HttpOverrides {}

class LiveTransport extends HttpTransport {
  LiveTransport(String url)
    : super(baseUrl: url, client: _RealHttp().createHttpClient(null));
  final requests = <String>[];
  final createdDocuments = <String>[];
  @override
  Future<HttpTransportResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    requests.add('POST $path');
    final response = await super.post(path, headers: headers, body: body);
    if (response.statusCode == 201 &&
        (path == '/protected/delivery-route-sheets/create' ||
            path == '/protected/pickup-sheets/create')) {
      final data = (jsonDecode(response.body) as Map)['data'] as Map;
      createdDocuments.add(
        '${path.replaceFirst('/create', '')}/${data['deliveryDocumentId']}',
      );
    }
    return response;
  }
}

void main() {
  final enabled = Platform.environment['LIVE_DELIVERY_DAYS'] == 'true';
  testWidgets(
    'real Flutter widgets and HTTP delivery-days lifecycle',
    (tester) async {
      final username = Platform.environment['LIVE_API_USERNAME'];
      final password = Platform.environment['LIVE_API_PASSWORD'];
      expect(username, isNotNull, reason: 'Set LIVE_API_USERNAME');
      expect(password, isNotNull, reason: 'Set LIVE_API_PASSWORD');
      final configuredUrl = Uri.parse(
        Platform.environment['LIVE_API_URL'] ?? 'http://127.0.0.1:8000',
      );
      // Avoid IPv6 localhost fallback timers inside the headless fake-clock runner.
      final transport = LiveTransport(
        configuredUrl.host == 'localhost'
            ? configuredUrl.replace(host: '127.0.0.1').toString()
            : configuredUrl.toString(),
      );
      final auth = AuthServiceImpl(
        repository: AuthRepositoryImpl(
          dataSource: AuthApiDataSource(transport: transport),
        ),
        tokenStorage: MemoryTokenStorage(),
      );
      final api = ApiClient(
        transport: transport,
        authService: auth,
        userAgent: 'MountainFairytale/LiveCheck',
      );
      final routeRepo = DeliveryRouteRepositoryImpl(
        ApiDeliveryRouteDataSource(api),
      );
      final pickupRepo = PickupRepositoryImpl(ApiPickupDataSource(api));
      final dayRepo = ApiDeliveryRepository(ApiDeliveryDaysDataSource(api));
      final products = ProductRepositoryImpl(ApiProductDataSource(api));
      final clientsRepo = ClientRepositoryImpl(ApiClientDataSource(api));
      final cars = CarRepositoryImpl(ApiCarDataSource(api));
      final drivers = DriverRepositoryImpl(ApiDriverDataSource(api));
      final payments = PaymentMethodRepositoryImpl(
        ApiPaymentMethodDataSource(api),
      );
      final route = RouteConstructorProvider(
        carRepo: cars,
        driverRepo: drivers,
        routeRepo: routeRepo,
        printService: _NoPrinting(),
        productRepo: products,
        paymentMethodRepo: payments,
        clientRepo: clientsRepo,
      );
      final pickup = PickupConstructorProvider(
        pickupRepo: pickupRepo,
        productRepo: products,
        paymentMethodRepo: payments,
        clientRepo: clientsRepo,
      );
      final days = DeliveryDaysProvider(dayRepo);
      final clients = ClientsProvider(clientsRepo);
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeProvider(await SharedPreferences.getInstance());
      final scroll = ScrollController();
      final fixturePaths = <String>[];
      DateTime? originalFirst;
      var originalTotal = 0;
      final marker = 'LIVE-${DateTime.now().microsecondsSinceEpoch}';
      final originalName = '$marker Вода Горная';
      final newName = '$marker Вода Родниковая';

      Future<T> network<T>(Future<T> Function() body) async =>
          (await tester.runAsync(body)) as T;
      Map<String, dynamic> data(Map<String, dynamic> response) =>
          Map<String, dynamic>.from(response['data'] as Map);
      Future<void> settled(bool Function() ready) async {
        for (var i = 0; i < 300; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 40));
          final uiError = tester.takeException();
          if (uiError != null) fail('Live Flutter UI error: $uiError');
          if (ready() &&
              !days.isLoadingMore &&
              !route.documentBusy &&
              !pickup.documentBusy) {
            // A popped route can still expose the dialog while its barrier is
            // animating. Start and finish transition frames before the next tap.
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
            if (ready() &&
                find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              return;
            }
          }
        }
        fail(
          'Live UI did not settle; days=${days.errorMessage}, route=${route.documentError}, pickup=${pickup.documentError}, '
          'routeActive=${route.documentActive}, routeBusy=${route.documentBusy}, '
          'routeEditing=${route.isEditing}, recentRequests=${transport.requests.reversed.take(5).toList()}',
        );
      }

      Future<void> tap(String text) async {
        await tester.runAsync(() => tester.tap(find.text(text).last));
        await tester.pump();
      }

      Future<void> confirmStatus(String action) async {
        await tap(action);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final confirm = find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text(action),
        );
        expect(confirm, findsOneWidget);
        await tester.runAsync(() => tester.tap(confirm));
        await tester.pump();
      }

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await network(
          () => auth.login(username: username!, password: password!),
        );
        final baseline = await network(
          () => dayRepo.getDeliveryDays(offset: 0, limit: 1),
        );
        originalTotal = baseline.total;
        expect(
          originalTotal,
          greaterThan(0),
          reason: 'This non-destructive live scenario requires an existing calendar range',
        );
        final oldest = await network(
          () => dayRepo.getDeliveryDays(
            offset: max(0, baseline.total - 1),
            limit: 1,
          ),
        );
        originalFirst = oldest.days.isEmpty
            ? DateTime.now()
            : oldest.days.single.plannedDate;
        final newest = baseline.days.isEmpty
            ? DateTime.now()
            : baseline.days.single.plannedDate;
        final target = DateTime(newest.year, newest.month, newest.day + 3);
        final backdated = originalFirst.subtract(const Duration(days: 2));
        final fixture = await network(() async {
          final customer = data(
            await api.post(
              '/protected/clients/create',
              body: {
                'name': marker,
                'phone': 'live${DateTime.now().microsecondsSinceEpoch}',
                'address': 'Адрес совместной проверки',
                'sleepingThresholdDays': 10,
              },
            ),
          );
          fixturePaths.add('/protected/clients/${customer['clientId']}');
          final product = data(
            await api.post(
              '/protected/products/create',
              body: {'name': originalName, 'basePrice': 1.005},
            ),
          );
          fixturePaths.add('/protected/products/${product['productId']}');
          final driver = data(
            await api.post('/protected/drivers/create', body: {'name': marker}),
          );
          fixturePaths.add('/protected/drivers/${driver['driverId']}');
          final random = Random.secure();
          final number =
              'А${random.nextInt(1000).toString().padLeft(3, '0')}ВК${100 + random.nextInt(900)}';
          final car = data(
            await api.post(
              '/protected/cars/create',
              body: {'model': marker, 'number': number},
            ),
          );
          fixturePaths.add('/protected/cars/${car['carId']}');
          return (
            customer['clientId'] as String,
            product['productId'] as String,
            driver['driverId'] as String,
            car['carId'] as String,
          );
        });
        await network(days.fetchDeliveryDays);
        await tester.pumpWidget(
          RepaintBoundary(
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: route),
                ChangeNotifierProvider.value(value: pickup),
                ChangeNotifierProvider.value(value: days),
                ChangeNotifierProvider.value(value: clients),
                ChangeNotifierProvider.value(value: theme),
              ],
              child: MaterialApp(
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SizedBox(
                    width: 500,
                    child: DeliveryDaysListView(scrollController: scroll),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        debugPrint('LIVE: creating delivery');
        await tap('Добавить доставку');
        await tester.pump(const Duration(milliseconds: 300));
        await tap('Доставка');
        await settled(
          () =>
              find.text('Сохранить').evaluate().isNotEmpty &&
              !route.isLoadingDirectories,
        );
        await network(() async {
          route.setDate(target);
          route.selectExistingDriver(await drivers.getDriverById(fixture.$3));
          route.selectExistingCar(await cars.getCarById(fixture.$4));
          route.addClientPoint(await clientsRepo.getClientById(fixture.$1));
          expect(
            await route.addCurrentProduct(
              0,
              fixture.$2,
              3,
              productName: originalName,
            ),
            isTrue,
          );
        });
        await tester.pump();
        await tap('Сохранить');
        await settled(
          () => find.byType(DeliveryDaysListView).evaluate().isNotEmpty,
        );
        expect(days.total, originalTotal + 3);
        expect(days.days.first.totalAmount, 3.02);
        expect(days.days.first.deliveryPointsCount, 1);
        debugPrint('LIVE: delivery saved');
        final routeId = route.documentId!;
        await tester.tap(find.byType(DeliveryDayItem).first);
        await settled(
          () => find.text(marker).evaluate().isNotEmpty,
        );
        expect(find.byType(DayDocumentsDialog), findsOneWidget);

        await network(
          () => api.patch(
            '/protected/products/${fixture.$2}',
            body: {'name': newName, 'basePrice': 2.675},
          ),
        );
        final savedRoute = await network(
          () => routeRepo.getRouteSheetById(routeId),
        );
        expect(savedRoute.points.single.items.single.productName, originalName);
        debugPrint('LIVE: catalog renamed, opening pickup');
        await tap('Добавить самовывоз');
        await settled(
          () =>
              find.text('Сохранить').evaluate().isNotEmpty &&
              !pickup.isLoadingDirectories,
        );
        expect(pickup.selectedDate, target);
        debugPrint('LIVE: pickup editor ready');
        await network(() async {
          pickup.addClientPoint(await clientsRepo.getClientById(fixture.$1));
          expect(
            await pickup.addCurrentProduct(
              0,
              fixture.$2,
              1,
              productName: newName,
            ),
            isTrue,
          );
        });
        await tester.pump();
        await tap('Сохранить');
        await settled(
          () => find.byType(DayDocumentsDialog).evaluate().isNotEmpty,
        );
        expect(days.days.first.totalAmount, 5.70);
        debugPrint('LIVE: pickup saved');
        expect(days.days.first.pickupPointsCount, 1);
        expect(days.days.first.products.single.quantity, 4);
        expect(
          days.days.first.products.single.productName,
          [originalName, newName].join(' / '),
        );

        final locksBeforeRead = transport.requests
            .where((r) => r.endsWith('/edit-lock'))
            .length;
        await tap(marker);
        await settled(
          () => find.text('Начать редактирование').evaluate().isNotEmpty,
        );
        expect(
          transport.requests.where((r) => r.endsWith('/edit-lock')).length,
          locksBeforeRead,
        );
        await confirmStatus('Отменить документ');
        await settled(() => !route.documentActive);
        expect(days.days.first.totalAmount, 2.68);
        expect(days.days.first.deliveryPointsCount, 0);
        debugPrint('LIVE: cancellation reflected in card');
        await tap('Закрыть');
        await settled(
          () => find.byType(DayDocumentsDialog).evaluate().isNotEmpty,
        );
        expect(find.text(marker), findsNothing);
        await tester.tap(find.byType(Switch));
        await settled(
          () => find.text(marker).evaluate().isNotEmpty,
        );
        await tap(marker);
        await settled(() => find.text('Восстановить').evaluate().isNotEmpty);
        await confirmStatus('Восстановить');
        await settled(() => route.documentActive);
        expect(days.days.first.totalAmount, 5.70);
        debugPrint('LIVE: restoration reflected in card');
        await tap('Начать редактирование');
        await settled(() => route.isEditing);
        route.updateTaskQuantity(0, 0, 4);
        await tester.pump();
        await tap('Сохранить');
        await settled(
          () => find.byType(DayDocumentsDialog).evaluate().isNotEmpty,
        );
        expect(days.days.first.totalAmount, 6.70);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

        await tap(marker);
        await settled(
          () => find.text('Начать редактирование').evaluate().isNotEmpty,
        );
        await tap('Начать редактирование');
        await settled(() => route.isEditing);
        await tap(marker);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(
          () => tester.tap(find.byTooltip('Обновить цену из каталога')),
        );
        await settled(() => find.text('Обновить цену').evaluate().isNotEmpty);
        await tap('Обновить цену');
        await tester.pump(const Duration(milliseconds: 350));
        expect(route.points.single.items.single.price, 2.675);
        expect(route.points.single.items.single.productName, originalName);
        await tap('Сохранить');
        await settled(
          () => find.byType(DayDocumentsDialog).evaluate().isNotEmpty,
        );
        expect(days.days.first.totalAmount, 13.38);
        debugPrint('LIVE: explicit price refresh preserved historical name');

        await tester.runAsync(
          () => tester.tap(
            find.ancestor(
              of: find.byIcon(Icons.store_outlined),
              matching: find.byType(AppDialogCard),
            ),
          ),
        );
        await settled(
          () => find.text('Начать редактирование').evaluate().isNotEmpty,
        );
        await tap('Начать редактирование');
        await settled(() => pickup.isEditing);
        pickup.setDate(backdated);
        await tester.pump();
        await tap('Сохранить');
        await settled(
          () => find.byType(DayDocumentsDialog).evaluate().isNotEmpty,
        );
        expect(
          find.ancestor(
            of: find.byIcon(Icons.store_outlined),
            matching: find.byType(AppDialogCard),
          ),
          findsNothing,
        );
        expect(days.total, originalTotal + 5);
        expect(days.days.first.totalAmount, 10.70);
        final earliest = await network(
          () => dayRepo.getDeliveryDays(offset: days.total - 1, limit: 1),
        );
        expect(earliest.days.single.plannedDate, backdated);
        expect(earliest.days.single.totalAmount, 2.68);
        debugPrint('LIVE: transfer expanded calendar and refreshed both days');

        await tap('Добавить самовывоз');
        await settled(
          () =>
              find.text('Сохранить').evaluate().isNotEmpty &&
              !pickup.isLoadingDirectories,
        );
        expect(pickup.selectedDate, target);
        await tap('Закрыть');
        await settled(
          () => find.byType(DayDocumentsDialog).evaluate().isNotEmpty,
        );
        expect(
          transport.createdDocuments.length,
          2,
          reason: 'Closing a new editor must not create a draft',
        );
        await tap('Закрыть');
        await settled(() => find.byType(DayDocumentsDialog).evaluate().isEmpty);
        await tester.tap(find.byType(DeliveryDayItem).at(1));
        await settled(
          () => find
              .text('На эту дату нет активных документов')
              .evaluate()
              .isNotEmpty,
        );
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
        await tap('Добавить самовывоз');
        await settled(
          () =>
              find.text('Сохранить').evaluate().isNotEmpty &&
              !pickup.isLoadingDirectories,
        );
        expect(pickup.selectedDate, target.subtract(const Duration(days: 1)));
        pickup.setDate(originalFirst.subtract(const Duration(days: 3)));
        await tester.pump();
        await tap('Сохранить');
        await settled(
          () => find
              .text('На эту дату нет активных документов')
              .evaluate()
              .isNotEmpty,
        );
        expect(days.total, originalTotal + 6);
        final blank = await network(
          () => dayRepo.getDeliveryDays(offset: days.total - 1, limit: 1),
        );
        expect(blank.days.single.pickupPointsCount, 0);
        expect(blank.days.single.products, isEmpty);
        expect(blank.days.single.totalAmount, 0);
        debugPrint(
          'LIVE: empty-day dialog and backdated draft creation verified',
        );
        await tap('Закрыть');
        await settled(() => find.byType(DayDocumentsDialog).evaluate().isEmpty);
        expect(tester.takeException(), isNull);
        await network(() async {
          await Directory('build/live-delivery-days').create(recursive: true);
          return File('build/live-delivery-days/saved-route.json')
              .writeAsString(jsonEncode(savedRoute.toJson()));
        });
        debugPrint('LIVE: UI scenarios completed');
      } finally {
        debugPrint('LIVE: cleaning up created fixtures');
        await network(() async {
          for (final path in transport.createdDocuments) {
            final document = data(await api.get(path));
            if (document['isActive'] == false) await api.post('$path/restore');
            await api.post('$path/edit-lock');
            await api.patch(
              path,
              body: {
                'plannedDate': originalFirst!.toIso8601String().substring(
                  0,
                  10,
                ),
              },
            );
            await api.post('$path/cancel');
          }
          for (final path in fixturePaths.reversed) {
            await api.patch(path, body: {'isActive': false});
          }
          if (originalFirst != null) {
            final after = await dayRepo.getDeliveryDays(offset: 0, limit: 1);
            expect(
              after.total,
              originalTotal,
              reason: 'Cleanup must restore original calendar boundaries',
            );
          }
        });
        await tester.pumpWidget(const SizedBox.shrink());
        route.dispose();
        pickup.dispose();
        days.dispose();
        clients.dispose();
        theme.dispose();
        scroll.dispose();
        auth.dispose();
        transport.close();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test('PDF uses the live saved snapshot after catalog rename', () async {
    final json = jsonDecode(
      await File('build/live-delivery-days/saved-route.json').readAsString(),
    ) as Map<String, dynamic>;
    final sheet = DeliveryRouteSheet.fromJson(json);
    final pdf = await RouteSheetPdfBuilder().build(sheet);
    await File('build/live-delivery-days/historical-route.pdf')
        .writeAsBytes(pdf);
    expect(pdf.length, greaterThan(1000));
  }, skip: !enabled);
}

class _NoPrinting implements RoutePrintService {
  @override
  Future<void> printRouteSheet(DeliveryRouteSheet sheet) async =>
      throw UnsupportedError('Do not send live checks to a physical printer');
}
