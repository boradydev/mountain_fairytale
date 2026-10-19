import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_meta_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/car_replacement_dialog.dart';

import 'constructors_test.dart'
    show Cars, Drivers, Routes, Products, PaymentDirectory, PrintService;
import 'document_provider_test.dart' show Clients;

const carA = Car(
  id: 'car',
  model: 'Газель',
  number: 'А123АА77',
  currentMileage: 800,
);
const carB = Car(
  id: 'other',
  model: 'Фургон',
  number: 'Б456ББ77',
  currentMileage: 1500,
);

class MileageCars extends Cars {
  @override
  Future<List<Car>> getAvailableCars({bool includeDeactivated = false}) async =>
      [carA, carB];
  @override
  Future<Car> getCarById(String id) async => id == carA.id ? carA : carB;
}

class MileageDrivers extends Drivers {
  @override
  Driver get driver => Driver(
    id: 'driver',
    name: 'Водитель',
    createdAt: DateTime(2026),
    isActive: true,
  );
  @override
  Future<List<Driver>> getAvailableDrivers({
    bool includeDeactivated = false,
  }) async => [driver];
}

class MileageRoutes extends Routes {
  Map<String, dynamic>? request;
  bool fail = false;
  @override
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet value) async {
    request = value.toRequestJson();
    if (fail) throw Exception('save failed');
    return super.saveRouteSheet(value);
  }
}

RouteConstructorProvider makeProvider(MileageRoutes routes) =>
    RouteConstructorProvider(
      carRepo: MileageCars(),
      driverRepo: MileageDrivers(),
      routeRepo: routes,
      printService: PrintService(),
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo: Clients(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'switching cars resets both readings and never remembers manual values',
    () async {
      final p = makeProvider(MileageRoutes());
      addTearDown(p.dispose);
      p.resetForm();
      await p.selectCar(carA);
      p.startMileage = 810;
      p.endMileage = 900;
      expect(p.distance, 90);
      await p.selectCar(carB);
      expect(p.startMileage, 1500);
      expect(p.endMileage, isNull);
      await p.selectCar(carA);
      expect(p.startMileage, 800);
      expect(p.endMileage, isNull);
      p.endMileage = 800;
      expect(p.distance, 0);
    },
  );

  test('recorded replacement is deferred, cancellation preserves original, retry retains correction', () async {
    final repo = MileageRoutes();
    final p = makeProvider(repo);
    addTearDown(p.dispose);
    await p.loadExistingRouteById('document');
    expect(
      p.startMileage,
      100,
    ); // Historical reading survives current mileage 800.
    await p.beginEditing();
    p.confirmCarReplacement = (car, sheet) async {
      expect(car.currentMileage, 800); // Fresh car, not the historical end 200.
      return null;
    };
    expect(await p.selectCar(carB), isFalse);
    expect(p.selectedCar!.id, carA.id);
    expect(p.endMileage, 200);
    p.confirmCarReplacement = (car, sheet) async => (mileage: 90.0);
    expect(await p.selectCar(carB), isTrue);
    expect(p.startMileage, 1500);
    expect(p.endMileage, isNull);
    expect(repo.saved, 0);
    expect(p.currentRouteSheet!.toRequestJson()['previousCarMileage'], 90);
    repo.fail = true;
    expect(await p.saveRoute(), isFalse);
    expect(p.currentRouteSheet!.toRequestJson()['previousCarMileage'], 90);
    repo.fail = false;
    expect(await p.saveRoute(), isTrue);
    expect(repo.request!['carChangeConfirmed'], isTrue);
    expect(repo.request!['previousCarMileage'], 90);
    expect(
      p.currentRouteSheet!.toRequestJson().containsKey('previousCarMileage'),
      isFalse,
    );
    await p.closeDocument();
  });

  test('returning to original clears correction and resets readings; cancel restores server values', () async {
    final repo = MileageRoutes();
    final p = makeProvider(repo);
    addTearDown(p.dispose);
    await p.loadExistingRouteById('document');
    await p.beginEditing();
    p.confirmCarReplacement = (_, _) async => (mileage: 90.0);
    await p.selectCar(carB);
    await p.selectCar(carA);
    expect(p.startMileage, 800);
    expect(p.endMileage, isNull);
    expect(
      p.currentRouteSheet!.toRequestJson().containsKey('carChangeConfirmed'),
      isFalse,
    );
    expect(
      p.currentRouteSheet!.toRequestJson().containsKey('previousCarMileage'),
      isFalse,
    );
    await p.selectCar(carB);
    await p.cancelEditing();
    expect(p.startMileage, 100);
    expect(p.endMileage, 200);
    expect(p.selectedCar!.id, carA.id);
    expect(repo.saved, 0);
    expect(
      p.currentRouteSheet!.toRequestJson().containsKey('previousCarMileage'),
      isFalse,
    );
  });

  test(
    'empty correction confirms replacement without odometer mutation',
    () async {
      final p = makeProvider(MileageRoutes());
      addTearDown(p.dispose);
      await p.loadExistingRouteById('document');
      await p.beginEditing();
      p.confirmCarReplacement = (_, _) async => (mileage: null);
      await p.selectExistingCar(carB);
      expect(p.selectedCar!.id, carB.id);
      expect(
        p.currentRouteSheet!.toRequestJson()['carChangeConfirmed'],
        isTrue,
      );
      expect(
        p.currentRouteSheet!.toRequestJson().containsKey('previousCarMileage'),
        isFalse,
      );
      await p.closeDocument();
    },
  );

  testWidgets(
    'distance updates on typing and switching cars clears visible end field',
    (tester) async {
      final p = makeProvider(MileageRoutes());
      addTearDown(p.dispose);
      p.resetForm();
      p.cars = [carA, carB];
      p.drivers = [MileageDrivers().driver];
      p.selectDriver(p.drivers.single);
      await p.selectCar(carA);
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Form(
                  key: key,
                  child: RouteMetaPanel(formKey: key),
                ),
              ),
            ),
          ),
        ),
      );
      final end = find.widgetWithText(TextFormField, 'Километраж заезда (км)');
      await tester.enterText(end, '925,5');
      await tester.pump();
      expect(find.text('Пробег доставки: 125.5 км'), findsOneWidget);
      await p.selectCar(carB);
      await tester.pump();
      expect(find.text('925,5'), findsNothing);
      expect(find.text('1500.0'), findsOneWidget);
      expect(find.text('Пробег доставки ещё не указан'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final input in <String?>[null, '', '75,5']) {
    testWidgets('replacement dialog handles cancel or correction "$input"', (
      tester,
    ) async {
      ({double? mileage})? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCarReplacementDialog(
                    context,
                    carA,
                    MileageRoutes().sheet,
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Текущий пробег: 800.0 км'), findsOneWidget);
      if (input == null) {
        await tester.tap(find.text('Отмена'));
      } else {
        await tester.enterText(find.byType(TextFormField), '-1');
        await tester.tap(find.text('Продолжить замену'));
        await tester.pumpAndSettle();
        expect(
          find.text('Введите корректный неотрицательный пробег'),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextFormField), input);
        await tester.tap(find.text('Продолжить замену'));
      }
      await tester.pumpAndSettle();
      if (input == null) {
        expect(result, isNull);
      } else {
        expect(result, (mileage: input.isEmpty ? null : 75.5));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
