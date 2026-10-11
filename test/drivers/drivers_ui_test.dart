import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/drivers/drivers_abcs.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/drivers/ui/driver_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_meta_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';
import 'package:mountain_fairytale/features/cars/cars_abcs.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';

class _Cars implements CarRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Routes implements DeliveryRouteRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Print implements RoutePrintService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Clients implements ClientRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Products implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Payments implements PaymentMethodRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final active = Driver(
  id: '00000000-0000-4000-8000-000000000001',
  name: 'Активный водитель',
  createdAt: DateTime(2026),
  isActive: true,
);
final inactive = Driver(
  id: '00000000-0000-4000-8000-000000000002',
  name: 'Неактивный водитель',
  createdAt: DateTime(2026),
  isActive: false,
);

class _Drivers implements DriverRepository {
  List<Driver> rows = [active, inactive];
  bool fail = false;
  int patches = 0;
  int creates = 0;
  Completer<List<Driver>>? loadGate;
  @override
  Future<List<Driver>> getAvailableDrivers({
    bool includeDeactivated = false,
  }) async => loadGate != null
      ? await loadGate!.future
      : rows.where((d) => includeDeactivated || d.isActive).toList();
  @override
  Future<Driver> updateDriver(String id, UpdateDriverRequest request) async {
    patches++;
    if (fail) throw Exception('offline');
    final old = rows.firstWhere((d) => d.id == id);
    final updated = Driver(
      id: old.id,
      name: request.name ?? old.name,
      createdAt: old.createdAt,
      isActive: request.isActive ?? old.isActive,
    );
    rows = rows.map((d) => d.id == id ? updated : d).toList();
    return updated;
  }

  @override
  Future<Driver?> checkDuplicate(String name) async => inactive;
  @override
  Future<Driver> createDriver(CreateDriverRequest request) async {
    creates++;
    return active;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

RouteConstructorProvider makeProvider(_Drivers repo) =>
    RouteConstructorProvider(
      carRepo: _Cars(),
      driverRepo: repo,
      routeRepo: _Routes(),
      printService: _Print(),
      productRepo: _Products(),
      paymentMethodRepo: _Payments(),
      clientRepo: _Clients(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('inactive filter persists and deactivation clears selection without deleting row', () async {
    final repo = _Drivers();
    final provider = makeProvider(repo);
    await provider.loadDrivers();
    expect(provider.drivers.length, 1);
    provider.selectDriver(provider.drivers.single);
    await provider.toggleInactiveDrivers(true);
    expect(provider.drivers.length, 2);
    expect(await provider.deactivateDriver(active.id), isTrue);
    expect(provider.selectedDriver, isNull);
    expect(provider.drivers.length, 2);
    expect(repo.rows.length, 2);
    final next = makeProvider(repo);
    await next.loadDrivers();
    expect(next.showInactiveDrivers, isTrue);
    expect(next.drivers.length, 2);
    provider.dispose();
    next.dispose();
  });

  test('failed activation preserves selection; inactive direct selection is rejected', () async {
    final repo = _Drivers()..fail = true;
    final provider = makeProvider(repo)..drivers = [active, inactive];
    provider.selectDriver(active);
    provider.selectDriver(inactive);
    expect(provider.selectedDriver, active);
    expect(await provider.activateAndSelectDriver(inactive), isFalse);
    expect(provider.selectedDriver, active);
    provider.dispose();
  });

  Future<void> panel(
    WidgetTester tester,
    RouteConstructorProvider provider,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: Form(
                key: GlobalKey<FormState>(),
                child: RouteMetaPanel(formKey: GlobalKey<FormState>()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'edit stays visible disabled without selection; panel fits 360px',
    (tester) async {
      final provider = makeProvider(_Drivers())..drivers = [active, inactive];
      await panel(tester, provider);
      final edit = find.widgetWithIcon(IconButton, Icons.edit_outlined);
      expect(edit, findsOneWidget);
      expect(tester.widget<IconButton>(edit).onPressed, isNull);
      provider.selectDriver(active);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(edit).onPressed, isNotNull);
      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(edit).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('eye toggle keeps all action buttons in place while loading', (
    tester,
  ) async {
    final repo = _Drivers()..loadGate = Completer<List<Driver>>();
    final provider = makeProvider(repo)..drivers = [active];
    provider.selectDriver(active);
    await panel(tester, provider);
    final add = find.widgetWithIcon(IconButton, Icons.add).first;
    final edit = find.widgetWithIcon(IconButton, Icons.edit_outlined).first;
    final addPosition = tester.getCenter(add);
    final editPosition = tester.getCenter(edit);
    final driverField = find.byType(DropdownButtonFormField<Driver>);
    final carField = find.byType(DropdownButtonFormField<Car>);
    final driverState = tester.state(driverField);
    final driverRect = tester.getRect(driverField);
    final carRect = tester.getRect(carField);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.isLoadingDrivers, isTrue);
    expect(tester.widget<IconButton>(add).onPressed, isNull);
    expect(tester.getCenter(add), addPosition);
    expect(tester.getCenter(edit), editPosition);
    expect(tester.getRect(driverField), driverRect);
    expect(tester.getRect(carField), carRect);
    expect(tester.state(driverField), same(driverState));
    repo.loadGate!.complete([
      Driver.fromJson(active.toJson()),
      Driver.fromJson(inactive.toJson()),
    ]);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(add).onPressed, isNotNull);
    expect(tester.getCenter(add), addPosition);
    expect(tester.getCenter(edit), editPosition);
    expect(tester.getRect(driverField), driverRect);
    expect(tester.getRect(carField), carRect);
    expect(tester.state(driverField), same(driverState));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel inactive activation keeps selected driver and dropdown in sync',
    (tester) async {
      final repo = _Drivers();
      final provider = makeProvider(repo)..drivers = [active, inactive];
      provider.selectDriver(active);
      await panel(tester, provider);
      await tester.tap(find.text(active.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${inactive.name} — Неактивен').last);
      await tester.pumpAndSettle();
      expect(find.text('Водитель неактивен'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(provider.selectedDriver, active);
      expect(repo.patches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duplicate activation closes both dialogs and selects server record',
    (tester) async {
      final repo = _Drivers();
      final provider = makeProvider(repo)..drivers = [active, inactive];
      await panel(tester, provider);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DriverDialog),
          matching: find.byType(TextFormField),
        ),
        'Иванов',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Найден водитель с похожим именем'), findsOneWidget);
      await tester.tap(find.text('Активировать').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Водитель неактивен'), findsOneWidget);
      await tester.tap(find.text('Активировать и выбрать'));
      await tester.pumpAndSettle();
      expect(provider.selectedDriver!.id, inactive.id);
      expect(provider.selectedDriver!.isActive, isTrue);
      expect(repo.creates, 0);
      expect(repo.patches, 1);
      expect(find.byType(DriverDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'inactive duplicate offers activation before saving and cancel preserves form',
    (tester) async {
      final repo = _Drivers();
      final provider = makeProvider(repo)..drivers = [active, inactive];
      provider.selectDriver(active);
      await panel(tester, provider);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first);
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(DriverDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field, 'Иванов');
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Активировать'), findsOneWidget);
      await tester.tap(find.text('Активировать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Водитель неактивен'), findsOneWidget);
      await tester.tap(find.text('Отмена').last);
      await tester.pumpAndSettle();
      expect(provider.selectedDriver, active);
      expect(repo.patches, 0);
      expect(find.byType(DriverDialog), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, 'Иванов');
      await tester.tap(find.text('Активировать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Активировать и выбрать'));
      await tester.pumpAndSettle();
      expect(provider.selectedDriver!.id, inactive.id);
      expect(repo.patches, 1);
      expect(repo.creates, 0);
      expect(find.byType(DriverDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
