import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/cars/cars_abcs.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/drivers/drivers_abcs.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';

import 'document_provider_test.dart' show Catalog, Payments, Clients, point;

class Products extends Catalog {
  @override
  Future<List<Product>> getAvailableProducts({
    bool includeDeactivated = false,
  }) async => [];
}

class PaymentDirectory extends Payments {
  @override
  Future<List<PaymentMethod>> getAllPaymentMethods({
    bool includeDeactivated = false,
  }) async => [];
}

class Drivers implements DriverRepository {
  final driver = Driver(
    id: 'driver',
    name: 'Водитель',
    createdAt: DateTime(2026),
    isActive: false,
  );
  @override
  Future<List<Driver>> getAvailableDrivers({
    bool includeDeactivated = false,
  }) async => includeDeactivated ? [driver] : [];
  @override
  Future<Driver> getDriverById(String id) async =>
      Driver.fromJson(driver.toJson());
  @override
  Future<Driver> updateDriver(String id, UpdateDriverRequest request) async =>
      Driver.fromJson(driver.toJson());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Cars implements CarRepository {
  final car = const Car(
    id: 'car',
    model: 'Авто',
    number: 'А123АА',
    currentMileage: 800,
    isActive: false,
  );
  int updates = 0;
  Completer<Car>? loadGate;
  Completer<void>? requested;
  @override
  Future<List<Car>> getAvailableCars({bool includeDeactivated = false}) async =>
      includeDeactivated ? [car] : [];
  @override
  Future<Car> getCarById(String id) async {
    requested?.complete();
    return loadGate == null ? car : await loadGate!.future;
  }

  @override
  Future<Car> updateCar(String id, UpdateCarRequest request) async {
    updates++;
    return car;
  }

  @override
  Future<Car> deactivateCar(String id) async => car;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PrintService implements RoutePrintService {
  @override
  Future<void> printRouteSheet(DeliveryRouteSheet sheet) async {}
}

class Routes implements DeliveryRouteRepository {
  DeliveryRouteSheet sheet = DeliveryRouteSheet(
    id: 'document',
    date: DateTime(2025, 3, 15),
    createdAt: DateTime(2026, 10, 13),
    driverId: 'driver',
    driverName: 'Водитель',
    carId: 'car',
    carModelAndNumber: 'Авто А123АА',
    startMileage: 100,
    endMileage: 200,
    points: [],
  );
  int saved = 0, acquired = 0, released = 0;
  @override
  Future<DeliveryRouteSheet> getRouteSheetById(String id) async => sheet;
  @override
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet value) async {
    saved++;
    sheet = DeliveryRouteSheet.fromJson(value.toJson());
    return sheet;
  }

  @override
  Future<DeliveryRouteSheet> cancelRouteSheet(String id) async {
    sheet = DeliveryRouteSheet.fromJson({...sheet.toJson(), 'isActive': false});
    return sheet;
  }

  @override
  Future<DeliveryRouteSheet> restoreRouteSheet(String id) async {
    sheet = DeliveryRouteSheet.fromJson({...sheet.toJson(), 'isActive': true});
    return sheet;
  }

  @override
  Future<String> acquireEditLock(String id) async {
    acquired++;
    return 'manager';
  }

  @override
  Future<String> renewEditLock(String id) async => 'manager';
  @override
  Future<void> releaseEditLock(String id) async {
    released++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Pickups implements PickupRepository {
  PickupSheet? sheet;
  int creates = 0, updates = 0, releases = 0;
  @override
  Future<PickupSheet> getPickupSheetById(String id) async => sheet!;
  @override
  Future<PickupSheet> savePickupSheet(PickupSheet value) async {
    if (value.id == null) {
      creates++;
    } else {
      updates++;
    }
    sheet = PickupSheet.fromJson({
      ...value.toJson(),
      'deliveryDocumentId': 'new-document',
      'createdAt': '2026-10-13T10:00:00',
    });
    return sheet!;
  }

  @override
  Future<String> acquireEditLock(String id) async => 'manager';
  @override
  Future<String> renewEditLock(String id) async => 'manager';
  @override
  Future<void> releaseEditLock(String id) async {
    releases++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('assigned inactive resources stay in dropdowns after an update', () async {
    final p = RouteConstructorProvider(
      carRepo: Cars(),
      driverRepo: Drivers(),
      routeRepo: Routes(),
      printService: PrintService(),
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo: Clients(),
    );
    addTearDown(p.dispose);
    await p.loadExistingRouteById('document');
    expect(p.showInactiveDrivers, isFalse);
    expect(await p.deactivateDriver('driver'), isTrue);
    expect(p.selectedDriver, isNotNull);
    expect(p.drivers.where((d) => d == p.selectedDriver), hasLength(1));
    expect(await p.deactivateCar('car'), isTrue);
    expect(p.selectedCar, isNotNull);
    expect(p.cars.where((c) => c == p.selectedCar), hasLength(1));
  });

  test(
    'route refresh keeps dropdown selection valid while car is loading',
    () async {
      final cars = Cars();
      final p = RouteConstructorProvider(
        carRepo: cars,
        driverRepo: Drivers(),
        routeRepo: Routes(),
        printService: PrintService(),
        productRepo: Products(),
        paymentMethodRepo: PaymentDirectory(),
        clientRepo: Clients(),
      );
      addTearDown(p.dispose);
      await p.loadExistingRouteById('document');
      cars.loadGate = Completer<Car>();
      cars.requested = Completer<void>();
      final refresh = p.refreshForEditing();
      await cars.requested!.future;
      final matchesWhileLoading = p.drivers
          .where((d) => d == p.selectedDriver)
          .length;
      cars.loadGate!.complete(cars.car);
      await refresh;
      expect(matchesWhileLoading, 1);
      expect(p.drivers.where((d) => d == p.selectedDriver), hasLength(1));
    },
  );

  test('inactive assigned resources survive opening and unchanged PATCH; saving never updates car', () async {
    final routes = Routes();
    final cars = Cars();
    final p = RouteConstructorProvider(
      carRepo: cars,
      driverRepo: Drivers(),
      routeRepo: routes,
      printService: PrintService(),
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo: Clients(),
    );
    addTearDown(p.dispose);
    await p.loadExistingRouteById('document');
    expect(routes.acquired, 0);
    expect(p.selectedDate, DateTime(2025, 3, 15));
    expect(p.selectedDriver!.isActive, isFalse);
    expect(p.selectedCar!.isActive, isFalse);
    expect(p.startMileage, 100);
    expect(p.canSave, isFalse);
    expect(await p.beginEditing(), isTrue);
    p.endMileage = null;
    expect(await p.saveRoute(), isTrue);
    expect(routes.saved, 1);
    expect(routes.sheet.endMileage, isNull);
    expect(cars.updates, 0);
    p.setDate(DateTime(2025, 4, 1));
    expect(await p.saveRoute(), isFalse);
    expect(routes.saved, 1);
    // Cancel discards unsaved root fields as well as points; restore retains server state.
    p.startMileage = 999;
    expect(await p.changeDocumentActive(), isTrue);
    expect(p.documentActive, isFalse);
    expect(p.selectedDate, DateTime(2025, 3, 15));
    expect(p.startMileage, 100);
    expect(await p.changeDocumentActive(), isTrue);
    expect(p.documentActive, isTrue);
    expect(p.canSave, isFalse);
    expect(await p.closeDocument(), isTrue);
  });
  test('cancel route editing restores saved metadata and points without saving or cancelling document', () async {
    final repo = Routes();
    repo.sheet = DeliveryRouteSheet.fromJson({
      ...repo.sheet.toJson(),
      'points': [point.toJson()],
    });
    final p = RouteConstructorProvider(
      carRepo: Cars(),
      driverRepo: Drivers(),
      routeRepo: repo,
      printService: PrintService(),
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo: Clients(),
    );
    addTearDown(p.dispose);
    await p.loadExistingRouteById('document');
    expect(await p.beginEditing(), isTrue);
    p.selectedDate = DateTime(2026, 10, 16);
    p.startMileage = 999;
    p.endMileage = 1000;
    p.selectedDriver = null;
    p.selectedCar = null;
    p.updateTaskQuantity(0, 0, 9);
    p.removePoint(0);
    expect(await p.cancelEditing(), isTrue);
    expect(p.selectedDate, repo.sheet.date);
    expect(p.startMileage, 100);
    expect(p.endMileage, 200);
    expect(p.selectedDriver!.id, 'driver');
    expect(p.selectedCar!.id, 'car');
    expect(p.points.single.items.single.quantity, 2);
    expect(p.documentActive, isTrue);
    expect(p.isEditing, isFalse);
    expect(p.documentChanged, isFalse);
    expect(repo.saved, 0);
    expect(repo.released, 1);
    expect(await p.beginEditing(), isTrue);
    expect(repo.acquired, 2);
    await p.closeDocument();
  });
  test(
    'cancel pickup editing restores saved date and items without saving',
    () async {
      final repo = Pickups()
        ..sheet = PickupSheet(
          id: 'pickup',
          date: DateTime(2026, 10, 15),
          points: [point],
        );
      final p = PickupConstructorProvider(
        pickupRepo: repo,
        productRepo: Products(),
        paymentMethodRepo: PaymentDirectory(),
        clientRepo: Clients(),
      );
      addTearDown(p.dispose);
      await p.loadExistingPickupById('pickup');
      expect(await p.beginEditing(), isTrue);
      p.setDate(DateTime(2026, 10, 16));
      p.updateTaskQuantity(0, 0, 9);
      expect(await p.cancelEditing(), isTrue);
      expect(p.selectedDate, DateTime(2026, 10, 15));
      expect(p.points.single.items.single.quantity, 2);
      expect(p.documentActive, isTrue);
      expect(p.canSave, isFalse);
      expect(repo.updates, 0);
      expect(repo.creates, 0);
      expect(repo.releases, 1);
      await p.closeDocument();
      expect(repo.releases, 1);
    },
  );
  test('blank pickup creation retains server ID; subsequent save requires an explicit lock', () async {
    final repo = Pickups();
    final p = PickupConstructorProvider(
      pickupRepo: repo,
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo: Clients(),
    );
    addTearDown(p.dispose);
    p.resetForm();
    p.setDate(DateTime(2025, 3, 15));
    expect(await p.savePickup(), isTrue);
    expect(p.currentPickupId, 'new-document');
    expect(p.documentCreatedAt, DateTime(2026, 10, 13, 10));
    expect(p.points, isEmpty);
    expect(await p.savePickup(), isFalse);
    expect(repo.creates, 1);
    expect(await p.beginEditing(), isTrue);
    expect(await p.savePickup(), isTrue);
    expect(repo.creates, 1);
    expect(repo.updates, 1);
    expect(await p.closeDocument(), isTrue);
    expect(repo.releases, 1);
  });
}
