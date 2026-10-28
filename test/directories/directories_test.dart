import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/directories/ui/directories_provider.dart';
import 'package:mountain_fairytale/features/directories/ui/directories_screen.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';

import '../delivery_documents/constructors_test.dart' as ctors;
import '../delivery_documents/document_provider_test.dart' as base;

class Store {
  final rows = {
    for (final section in DirectorySection.values)
      section: <Map<String, dynamic>>[
        {
          idKey(section): section.name,
          'name': 'Исходный ${section.name}',
          'model': 'Исходный ${section.name}',
          'number': 'А123АА126',
          'currentMileage': 1000.0,
          'basePrice': 350.0,
          'phone': '+79991234567',
          'commissionPercent': 5.0,
          'createdAt': '2026-10-28T10:00:00',
          'isActive': true,
        },
      ],
  };
  static String idKey(DirectorySection s) => switch (s) {
    DirectorySection.products => 'productId',
    DirectorySection.drivers => 'driverId',
    DirectorySection.cars => 'carId',
    DirectorySection.paymentMethods => 'paymentMethodId',
    DirectorySection.representatives => 'salesRepresentativeId',
  };
  bool failReads = false;
  bool failWrites = false;
  Completer<List<Product>>? productGate;
  final writes = <(DirectorySection, Map<String, dynamic>)>[];
  List<Map<String, dynamic>> list(DirectorySection s, bool include) {
    if (failReads) throw StateError('offline');
    return rows[s]!.where((r) => include || r['isActive'] == true).toList();
  }

  Map<String, dynamic> get(DirectorySection s, String id) =>
      rows[s]!.firstWhere((r) => r[idKey(s)] == id);
  Map<String, dynamic> patch(
    DirectorySection s,
    String id,
    Map<String, dynamic> body,
  ) {
    if (failWrites) throw StateError('offline');
    writes.add((s, body));
    final index = rows[s]!.indexWhere((r) => r[idKey(s)] == id);
    return rows[s]![index] = {...rows[s]![index], ...body};
  }

  Map<String, dynamic> create(DirectorySection s, Map<String, dynamic> body) {
    final value = {
      ...rows[s]!.first,
      ...body,
      idKey(s): '${s.name}-new',
      'isActive': true,
    };
    rows[s]!.insert(0, value);
    return value;
  }

  late final products = Products(this);
  late final drivers = Drivers(this);
  late final cars = Cars(this);
  late final payments = Payments(this);
  late final representatives = Representatives(this);
  final routes = ctors.Routes();
  RouteConstructorProvider newEditor() => RouteConstructorProvider(
    carRepo: cars,
    driverRepo: drivers,
    routeRepo: routes,
    printService: ctors.PrintService(),
    productRepo: products,
    paymentMethodRepo: payments,
    clientRepo: base.Clients(),
  );
  late final provider = DirectoriesProvider(
    products: products,
    drivers: drivers,
    cars: cars,
    paymentMethods: payments,
    representatives: representatives,
    createEditor: newEditor,
  );
}

class Products extends base.Catalog {
  final Store s;
  Products(this.s);
  @override
  Future<List<Product>> getAvailableProducts({
    bool includeDeactivated = false,
  }) async =>
      s.productGate?.future ??
      s
          .list(DirectorySection.products, includeDeactivated)
          .map(Product.fromJson)
          .toList();
  @override
  Future<Product> getProductById(String id) async =>
      Product.fromJson(s.get(DirectorySection.products, id));
  @override
  Future<Product> createProduct(CreateProductRequest r) async =>
      Product.fromJson(s.create(DirectorySection.products, r.toJson()));
  @override
  Future<Product> updateProduct(String id, UpdateProductRequest r) async =>
      Product.fromJson(s.patch(DirectorySection.products, id, r.toJson()));
  @override
  Future<Product?> checkDuplicate(String name) async => null;
}

class Drivers extends ctors.Drivers {
  final Store s;
  Drivers(this.s);
  @override
  Future<List<Driver>> getAvailableDrivers({
    bool includeDeactivated = false,
  }) async => s
      .list(DirectorySection.drivers, includeDeactivated)
      .map(Driver.fromJson)
      .toList();
  @override
  Future<Driver> getDriverById(String id) async =>
      Driver.fromJson(s.get(DirectorySection.drivers, id));
  @override
  Future<Driver> createDriver(CreateDriverRequest r) async =>
      Driver.fromJson(s.create(DirectorySection.drivers, r.toJson()));
  @override
  Future<Driver> updateDriver(String id, UpdateDriverRequest r) async =>
      Driver.fromJson(s.patch(DirectorySection.drivers, id, r.toJson()));
  @override
  Future<Driver?> checkDuplicate(String name) async => null;
}

class Cars extends ctors.Cars {
  final Store s;
  Cars(this.s);
  @override
  Future<List<Car>> getAvailableCars({bool includeDeactivated = false}) async =>
      s
          .list(DirectorySection.cars, includeDeactivated)
          .map(Car.fromJson)
          .toList();
  @override
  Future<Car> getCarById(String id) async =>
      Car.fromJson(s.get(DirectorySection.cars, id));
  @override
  Future<Car> createCar(CreateCarRequest r) async =>
      Car.fromJson(s.create(DirectorySection.cars, r.toJson()));
  @override
  Future<Car> updateCar(String id, UpdateCarRequest r) async =>
      Car.fromJson(s.patch(DirectorySection.cars, id, r.toJson()));
  @override
  Future<Car> deactivateCar(String id) async =>
      updateCar(id, const UpdateCarRequest(isActive: false));
  @override
  Future<Car?> checkDuplicate(String number) async => null;
}

class Payments extends base.Payments {
  final Store s;
  Payments(this.s);
  @override
  Future<List<PaymentMethod>> getAllPaymentMethods({
    bool includeDeactivated = false,
  }) async => s
      .list(DirectorySection.paymentMethods, includeDeactivated)
      .map(PaymentMethod.fromJson)
      .toList();
  @override
  Future<PaymentMethod> getPaymentMethodById(String id) async =>
      PaymentMethod.fromJson(s.get(DirectorySection.paymentMethods, id));
  @override
  Future<PaymentMethod> createPaymentMethod(
    CreatePaymentMethodRequest r,
  ) async => PaymentMethod.fromJson(
    s.create(DirectorySection.paymentMethods, r.toJson()),
  );
  @override
  Future<PaymentMethod> updatePaymentMethod(
    String id,
    UpdatePaymentMethodRequest r,
  ) async => PaymentMethod.fromJson(
    s.patch(DirectorySection.paymentMethods, id, r.toJson()),
  );
  @override
  Future<PaymentMethod?> checkDuplicate(String name) async => null;
}

class Representatives implements SalesRepresentativeApiRepository {
  final Store s;
  Representatives(this.s);
  @override
  Future<List<ApiSalesRepresentative>> getAll({
    bool includeDeactivated = false,
  }) async => s
      .list(DirectorySection.representatives, includeDeactivated)
      .map(ApiSalesRepresentative.fromJson)
      .toList();
  @override
  Future<ApiSalesRepresentative> get(String id) async =>
      ApiSalesRepresentative.fromJson(
        s.get(DirectorySection.representatives, id),
      );
  @override
  Future<ApiSalesRepresentative> create({
    required String name,
    required String phone,
    required double commissionPercent,
  }) async => ApiSalesRepresentative.fromJson(
    s.create(DirectorySection.representatives, {
      'name': name,
      'phone': phone,
      'commissionPercent': commissionPercent,
    }),
  );
  @override
  Future<ApiSalesRepresentative> update(
    String id,
    Map<String, dynamic> r,
  ) async => ApiSalesRepresentative.fromJson(
    s.patch(DirectorySection.representatives, id, r),
  );
  @override
  Future<ApiSalesRepresentative?> checkDuplicate(
    String name,
    String phone,
  ) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> open(
  WidgetTester tester,
  Store store, {
  Brightness brightness = Brightness.light,
  double width = 1400,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  addTearDown(store.provider.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: store.provider,
      child: MaterialApp(
        theme: AppTheme.createTheme(brightness),
        home: const Scaffold(body: DirectoriesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, DirectorySection section) async {
  final segment = find.descendant(
    of: find.byType(SegmentedButton<DirectorySection>),
    matching: find.text(section.label),
  );
  await tester.ensureVisible(segment);
  await tester.tap(segment);
  await tester.pumpAndSettle();
}

void main() {
  for (final section in DirectorySection.values) {
    testWidgets(
      '${section.name}: existing dialog edits and toggles activity without changing open document',
      (tester) async {
        final store = Store();
        final document = store.newEditor()
          ..points = [base.point]
          ..selectedDriver = Driver.fromJson(
            store.rows[DirectorySection.drivers]!.first,
          )
          ..selectedCar = Car.fromJson(
            store.rows[DirectorySection.cars]!.first,
          );
        addTearDown(document.dispose);
        final oldDriver = document.selectedDriver;
        final oldCar = document.selectedCar;
        await open(tester, store);
        await choose(tester, section);
        expect(find.byType(TextField), findsNothing);
        final add = find.text(section.addLabel);
        final originalName = 'Исходный ${section.name}';
        expect(
          tester.getTopLeft(add).dy,
          lessThan(tester.getTopLeft(find.text(originalName)).dy),
        );
        await tester.tap(find.text(originalName));
        await tester.pumpAndSettle();
        expect(find.text('Выбрать для маршрута'), findsNothing);
        final newName = 'Изменённый ${section.name}';
        await tester.enterText(find.byType(TextFormField).first, newName);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
        store.failWrites = true;
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsWidgets);
        expect(
          store.rows[section]!.first[section == DirectorySection.cars
              ? 'model'
              : 'name'],
          originalName,
        );
        store.failWrites = false;
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        expect(find.text(newName), findsOneWidget);
        expect(find.text(originalName), findsNothing);
        await tester.tap(find.text(newName));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Деактивировать'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Деактивировать').last);
        await tester.pumpAndSettle();
        expect(find.text(newName), findsNothing);
        await tester.tap(find.byType(LabeledCheckboxToggle));
        await tester.pumpAndSettle();
        expect(find.text(newName), findsOneWidget);
        expect(find.text('Деактивирован'), findsOneWidget);
        await tester.tap(find.text(newName));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Активировать'));
        // Existing product/payment forms keep their operation indicator active
        // behind the confirmation; wait for its route, not that indicator.
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Активировать и выбрать'), findsNothing);
        await tester.tap(find.text('Активировать').last);
        await tester.pumpAndSettle();
        expect(find.text('Активен'), findsOneWidget);
        expect(document.selectedDriver, same(oldDriver));
        expect(document.selectedCar, same(oldCar));
        expect(document.points, [base.point]);
        expect(document.grandTotal, base.point.totalAmount);
        expect(store.routes.saved, 0);
        expect(store.routes.acquired, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${section.name}: first add card reuses form and creates a record',
      (tester) async {
        final store = Store();
        await open(tester, store);
        await choose(tester, section);
        await tester.tap(find.text(section.addLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(store.rows[section], hasLength(1));
        await tester.tap(find.text(section.addLabel));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.first, 'Новая запись');
        switch (section) {
          case DirectorySection.products:
            await tester.enterText(fields.at(1), '500');
          case DirectorySection.cars:
            await tester.enterText(fields.at(1), 'А456АА126');
            await tester.enterText(fields.at(2), '2000');
          case DirectorySection.representatives:
            await tester.enterText(fields.at(1), '9991234598');
            await tester.enterText(fields.at(2), '5');
          default:
            break;
        }
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Добавить'));
        await tester.pumpAndSettle();
        expect(store.rows[section], hasLength(2));
        expect(find.text('Новая запись'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'each section remembers its filter; failures retry and stale loads are ignored',
    (tester) async {
      final store = Store();
      await open(tester, store, brightness: Brightness.dark, width: 900);
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      await choose(tester, DirectorySection.drivers);
      expect(store.provider.current.includeDeactivated, isFalse);
      store.failReads = true;
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Не удалось загрузить справочник'),
        findsOneWidget,
      );
      store.failReads = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(store.provider.current.error, isNull);
      await choose(tester, DirectorySection.products);
      expect(store.provider.current.includeDeactivated, isTrue);
      final old = Completer<List<Product>>();
      store.productGate = old;
      final pending = store.provider.refresh();
      store.productGate = null;
      await store.provider.setIncludeDeactivated(false);
      old.complete([]);
      await pending;
      await tester.pumpAndSettle();
      expect(store.provider.current.items, hasLength(1));
      expect(find.byType(AddActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
