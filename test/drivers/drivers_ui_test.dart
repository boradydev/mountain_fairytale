import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';

import 'dart:async';

import 'package:mountain_fairytale/core/theme.dart';

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
  Completer<Driver?>? duplicateGate;
  Completer<Driver>? createGate;
  Driver duplicate = inactive;
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
  Future<Driver?> checkDuplicate(String name) async =>
      duplicateGate == null ? duplicate : await duplicateGate!.future;
  @override
  Future<Driver> createDriver(CreateDriverRequest request) async {
    creates++;
    return createGate == null ? active : await createGate!.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

RouteConstructorProvider _makeProvider(_Drivers repo) =>
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
    final provider = _makeProvider(repo);
    await provider.loadDrivers();
    expect(provider.drivers.length, 1);
    provider.selectDriver(provider.drivers.single);
    await provider.toggleInactiveDrivers(true);
    expect(provider.drivers.length, 2);
    expect(await provider.deactivateDriver(active.id), isTrue);
    expect(provider.selectedDriver, isNull);
    expect(provider.drivers.length, 2);
    expect(repo.rows.length, 2);
    final next = _makeProvider(repo);
    await next.loadDrivers();
    expect(next.showInactiveDrivers, isTrue);
    expect(next.drivers.length, 2);
    provider.dispose();
    next.dispose();
  });

  test('failed activation preserves selection; inactive direct selection is rejected', () async {
    final repo = _Drivers()..fail = true;
    final provider = _makeProvider(repo)..drivers = [active, inactive];
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
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.createTheme(Brightness.light),
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

  testWidgets('inactive driver can be reactivated from its edit dialog', (
    tester,
  ) async {
    final repo = _Drivers();
    final provider = _makeProvider(repo)
      ..drivers = [active, inactive]
      ..selectedDriver = inactive;
    addTearDown(provider.dispose);
    await panel(tester, provider);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.edit_outlined).first,
    );
    await tester.pumpAndSettle();
    final activate = find.widgetWithText(OutlinedButton, 'Активировать');
    await tester.ensureVisible(activate);
    await tester.tap(activate);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Активировать и выбрать'),
    );
    await tester.pumpAndSettle();
    expect(repo.patches, 1);
    expect(repo.rows.firstWhere((d) => d.id == inactive.id).isActive, isTrue);
    expect(provider.selectedDriver!.id, inactive.id);
    expect(provider.selectedDriver!.isActive, isTrue);
    expect(find.byType(DriverDialog), findsNothing);
  });

  testWidgets('inactive driver uses disabled text color in document view', (
    tester,
  ) async {
    final provider = _makeProvider(_Drivers())
      ..initializeDocumentSession(id: 'saved-route')
      ..drivers = [inactive]
      ..selectedDriver = inactive;
    addTearDown(provider.dispose);
    await panel(tester, provider);
    final label = find.text('${inactive.name} — Неактивен');
    final text = tester.widget<Text>(label.first);
    expect(
      text.style!.color,
      Theme.of(tester.element(label.first)).disabledColor,
    );
    expect(provider.selectedDriver!.id, inactive.id);
  });

  testWidgets(
    'submit shows only duplicate spinner during check and fixed dialog progress during save',
    (tester) async {
      final duplicateGate = Completer<Driver?>();
      final createGate = Completer<Driver>();
      final repo = _Drivers()
        ..duplicateGate = duplicateGate
        ..createGate = createGate;
      final provider = _makeProvider(repo)..drivers = [active, inactive];
      addTearDown(provider.dispose);
      await panel(tester, provider);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first);
      await tester.pumpAndSettle();
      final dialog = find.byType(DriverDialog);
      final field = find.descendant(
        of: dialog,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field, 'Новый водитель');
      await tester.pump();
      final initialDialogRect = tester.getRect(dialog);
      final initialFieldRect = tester.getRect(field);
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      expect(
        find.descendant(
          of: dialog,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(DuplicateCheckStatusWidget),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.getRect(dialog), initialDialogRect);
      expect(tester.getRect(field), initialFieldRect);
      duplicateGate.complete(null);
      await tester.pump();
      expect(
        find.descendant(
          of: dialog,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(tester.getRect(dialog), initialDialogRect);
      expect(tester.getRect(field), initialFieldRect);
      createGate.complete(
        Driver(
          id: 'new-driver',
          name: 'Новый водитель',
          createdAt: DateTime(2026),
          isActive: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(repo.creates, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'edit stays visible disabled without selection; panel fits 360px',
    (tester) async {
      final provider = _makeProvider(_Drivers())..drivers = [active, inactive];
      await panel(tester, provider);
      final edit = find.descendant(
        of: find.byType(AppDropdown<Driver>),
        matching: find.widgetWithIcon(IconButton, Icons.edit_outlined),
      );
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
    final provider = _makeProvider(repo)..drivers = [active];
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
    final focusNode = tester
        .widget<AppDropdown<Driver>>(find.byType(AppDropdown<Driver>))
        .focusNode!;
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasPrimaryFocus, isTrue);
    await tester.tap(
      find.descendant(
        of: find.byType(AppDropdown<Driver>),
        matching: find.widgetWithIcon(
          IconButton,
          Icons.visibility_off_outlined,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.isLoadingDrivers, isTrue);
    expect(
      tester.widget<DropdownButtonFormField<Driver>>(driverField).onChanged,
      isNotNull,
    );
    expect(tester.widget<IconButton>(add).onPressed, isNotNull);
    expect(tester.widget<IconButton>(edit).onPressed, isNotNull);
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byType(AppDropdown<Driver>),
              matching: find.widgetWithIcon(
                IconButton,
                Icons.visibility_outlined,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(focusNode.hasPrimaryFocus, isTrue);
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
    expect(
      tester.widget<DropdownButtonFormField<Driver>>(driverField).onChanged,
      isNotNull,
    );
    expect(tester.getCenter(add), addPosition);
    expect(tester.getCenter(edit), editPosition);
    expect(tester.getRect(driverField), driverRect);
    expect(tester.getRect(carField), carRect);
    expect(tester.state(driverField), same(driverState));
    expect(tester.takeException(), isNull);
    expect(focusNode.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    'failed background refresh preserves list, selection and driver focus',
    (tester) async {
      final repo = _Drivers()..loadGate = Completer<List<Driver>>();
      final provider = _makeProvider(repo)..drivers = [active];
      provider.selectDriver(active);
      await panel(tester, provider);
      final field = find.byType(DropdownButtonFormField<Driver>);
      final focusNode = tester
          .widget<AppDropdown<Driver>>(find.byType(AppDropdown<Driver>))
          .focusNode!;
      focusNode.requestFocus();
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AppDropdown<Driver>),
          matching: find.widgetWithIcon(
            IconButton,
            Icons.visibility_off_outlined,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(provider.drivers, [active]);
      expect(provider.selectedDriver, active);
      repo.loadGate!.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(provider.drivers, [active]);
      expect(provider.selectedDriver, active);
      expect(focusNode.hasPrimaryFocus, isTrue);
      expect(
        find.text('Не удалось загрузить водителей. Повторите попытку.'),
        findsOneWidget,
      );
      expect(
        tester.widget<DropdownButtonFormField<Driver>>(field).onChanged,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byType(AppDropdown<Driver>),
                matching: find.widgetWithIcon(
                  IconButton,
                  Icons.visibility_outlined,
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel inactive activation keeps selected driver and dropdown in sync',
    (tester) async {
      final repo = _Drivers();
      final provider = _makeProvider(repo)..drivers = [active, inactive];
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
      final provider = _makeProvider(repo)..drivers = [active, inactive];
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
    'duplicate warning offers activation after submit and cancel preserves form',
    (tester) async {
      final repo = _Drivers();
      final provider = _makeProvider(repo)..drivers = [active, inactive];
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
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Активировать'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Найден водитель с похожим именем'), findsOneWidget);
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
      expect(find.text('Активировать'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
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
  Future<void> revealActiveDuplicate(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(DriverDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, 'Активный');
    await tester.pump();
    tester
        .widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)),
        )
        .focusNode!
        .unfocus();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать для маршрута'), findsNothing);
    await tester.tap(find.textContaining('Найден водитель с похожим именем:'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать для маршрута'), findsOneWidget);
    expect(find.text('Открыть существующего водителя'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  }

  testWidgets(
    'expanded active duplicate selects server record without creating or updating',
    (tester) async {
      final repo = _Drivers()..duplicate = Driver.fromJson(active.toJson());
      final provider = _makeProvider(repo)..drivers = [active];
      await panel(tester, provider);
      await revealActiveDuplicate(tester);
      await tester.tap(find.text('Выбрать для маршрута'));
      await tester.pumpAndSettle();
      expect(provider.selectedDriver, same(repo.duplicate));
      expect(provider.drivers.single, same(repo.duplicate));
      expect(repo.creates, 0);
      expect(repo.patches, 0);
      expect(find.byType(DriverDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded duplicate opens existing driver for editing without changing route selection',
    (tester) async {
      final repo = _Drivers()..duplicate = active;
      final provider = _makeProvider(repo)..drivers = [active];
      await panel(tester, provider);
      await revealActiveDuplicate(tester);
      await tester.tap(find.text('Открыть существующего водителя'));
      await tester.pumpAndSettle();
      expect(find.text('Редактирование водителя'), findsOneWidget);
      expect(
        tester.widget<DriverDialog>(find.byType(DriverDialog)).driver!.id,
        active.id,
      );
      final field = find.descendant(
        of: find.byType(DriverDialog),
        matching: find.byType(TextFormField),
      );
      expect(tester.widget<TextFormField>(field).controller!.text, active.name);
      expect(provider.selectedDriver, isNull);
      expect(repo.creates, 0);
      expect(repo.patches, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
