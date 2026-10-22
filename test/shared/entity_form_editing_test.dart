import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/products/ui/product_dialog.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_dialog.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/ui/car_dialog.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/drivers/ui/driver_dialog.dart';
import 'package:mountain_fairytale/features/employees/data/employee_model.dart';
import 'package:mountain_fairytale/features/employees/employees_abcs.dart';
import 'package:mountain_fairytale/features/employees/ui/employee_dialog.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_dialog.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_rep_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

import '../delivery_documents/document_provider_test.dart' as base;
import '../delivery_documents/constructors_test.dart' as ctors;
import '../clients/clients_ui_test.dart' as client_tests;

mixin _Requests {
  int checks = 0;
  Map<String, dynamic>? patch;
}

final _product = Product(
  id: 'p',
  name: 'Вода',
  basePrice: 100,
  createdAt: DateTime(2026),
  isActive: true,
);
final _payment = PaymentMethod(
  id: 'm',
  name: 'Наличные',
  createdAt: DateTime(2026),
  isActive: true,
);
const _car = Car(
  id: 'c',
  model: 'Авто',
  number: 'А123АА126',
  currentMileage: 100,
);
final _driver = Driver(
  id: 'd',
  name: 'Иванов',
  createdAt: DateTime(2026),
  isActive: true,
);
final _employee = Employee(
  id: 'e',
  username: 'manager',
  role: 'employee',
  commissionPercent: 10,
  isActive: true,
  createdAt: DateTime(2026),
);
const _representative = ApiSalesRepresentative(
  id: 'r',
  name: 'Представитель',
  phone: '+79123456789',
  commissionPercent: 10,
  isActive: true,
);

class _Products extends base.Catalog with _Requests {
  Completer<Product?>? gate;
  @override
  Future<Product?> checkDuplicate(String name) async {
    checks++;
    return gate == null ? null : await gate!.future;
  }

  @override
  Future<Product> updateProduct(String id, UpdateProductRequest request) async {
    patch = request.toJson();
    return _product;
  }
}

class _Payments extends base.Payments with _Requests {
  @override
  Future<PaymentMethod?> checkDuplicate(String name) async {
    checks++;
    return null;
  }

  @override
  Future<PaymentMethod> updatePaymentMethod(
    String id,
    UpdatePaymentMethodRequest request,
  ) async {
    patch = request.toJson();
    return _payment;
  }
}

class _Cars extends ctors.Cars with _Requests {
  @override
  Future<Car?> checkDuplicate(String number) async {
    checks++;
    return null;
  }

  @override
  Future<Car> updateCar(String id, UpdateCarRequest request) async {
    patch = request.toJson();
    return _car;
  }
}

class _Drivers extends ctors.Drivers with _Requests {
  @override
  Future<Driver?> checkDuplicate(String name) async {
    checks++;
    return null;
  }

  @override
  Future<Driver> updateDriver(String id, UpdateDriverRequest request) async {
    patch = request.toJson();
    return _driver;
  }
}

class _Employees with _Requests implements EmployeeRepository {
  @override
  Future<Employee?> checkDuplicate(String username) async {
    checks++;
    return null;
  }

  @override
  Future<Employee> updateEmployee(
    String id,
    UpdateEmployeeRequest request,
  ) async {
    patch = request.toJson();
    return _employee;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Representatives
    with _Requests
    implements SalesRepresentativeApiRepository {
  @override
  Future<ApiSalesRepresentative?> checkDuplicate(
    String name,
    String phone,
  ) async {
    checks++;
    return null;
  }

  @override
  Future<ApiSalesRepresentative> update(
    String id,
    Map<String, dynamic> changes,
  ) async {
    patch = changes;
    return _representative;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fixture {
  final products = _Products();
  final payments = _Payments();
  final cars = _Cars();
  final drivers = _Drivers();
  final employees = _Employees();
  final representatives = _Representatives();
  final clients = client_tests.ClientsFake();
  late final orders = RouteConstructorProvider(
    carRepo: cars,
    driverRepo: drivers,
    routeRepo: ctors.Routes(),
    printService: ctors.PrintService(),
    productRepo: products,
    paymentMethodRepo: payments,
    clientRepo: clients,
  );
  late final clientsProvider = ClientsProvider(clients);
  late final employeesProvider = EmployeesProvider(employees);
  void dispose() {
    orders.dispose();
    clientsProvider.dispose();
    employeesProvider.dispose();
  }

  Widget dialog(String kind) => switch (kind) {
    'product' => ProductDialog(provider: orders, product: _product),
    'payment' => PaymentMethodDialog(provider: orders, paymentMethod: _payment),
    'car' => const CarDialog(car: _car),
    'driver' => DriverDialog(driver: _driver),
    'employee' => EmployeeDialog(
      provider: employeesProvider,
      employee: _employee,
    ),
    'representative' => const SalesRepDialog(apiSalesRep: _representative),
    _ => ClientDialog(client: client_tests.row()),
  };
  Widget createDialog(String kind) {
    if (kind == 'representative') {
      return SalesRepDialog(
        apiSalesRep: _representative,
        apiRepository: representatives,
      );
    }
    return dialog(kind);
  }

  int checks(String kind) => switch (kind) {
    'product' => products.checks,
    'payment' => payments.checks,
    'car' => cars.checks,
    'driver' => drivers.checks,
    'employee' => employees.checks,
    'representative' => representatives.checks,
    _ => clients.checks,
  };
  Map<String, dynamic>? patch(String kind) => switch (kind) {
    'product' => products.patch,
    'payment' => payments.patch,
    'car' => cars.patch,
    'driver' => drivers.patch,
    'employee' => employees.patch,
    'representative' => representatives.patch,
    _ => clients.updated?.toJson(),
  };
}

Future<_Fixture> _open(WidgetTester tester, String kind) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final f = _Fixture();
  addTearDown(f.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: f.orders),
        ChangeNotifierProvider.value(value: f.clientsProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.createTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => f.createDialog(kind),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
  return f;
}

const _cases = {
  'product': ('Базовая цена *', '100.0', '200', 'basePrice', 200.0),
  'payment': ('Название *', 'Наличные', 'Карта', 'name', 'Карта'),
  'car': ('Модель автомобиля *', 'Авто', 'Новое авто', 'model', 'Новое авто'),
  'driver': ('ФИО водителя *', 'Иванов', 'Петров', 'name', 'Петров'),
  'employee': ('Комиссия', '10.0', '20', 'commissionPercent', 20.0),
  'representative': ('Вознаграждение', '10.0', '20', 'commissionPercent', 20.0),
  'client': (
    'Порог засыпания (в днях) *',
    '0',
    '2',
    'sleepingThresholdDays',
    2,
  ),
};
Finder _field(String label) => find.widgetWithText(TextFormField, label);
void main() {
  for (final entry in _cases.entries) {
    final kind = entry.key;
    final data = entry.value;
    testWidgets(
      '$kind: edits and reverts use stable OK/Save button without requests',
      (tester) async {
        final f = await _open(tester, kind);
        final rect = tester.getRect(
          find.widgetWithText(AppPrimaryButton, 'ОК'),
        );
        await tester.enterText(_field(data.$1), data.$3);
        await tester.pump();
        expect(
          tester.getRect(find.widgetWithText(AppPrimaryButton, 'Сохранить')),
          rect,
        );
        await tester.enterText(_field(data.$1), data.$2);
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('ОК'), findsOneWidget);
        expect(f.checks(kind), 0);
        expect(f.patch(kind), isNull);
        await tester.ensureVisible(find.text('ОК'));
        await tester.tap(find.text('ОК'));
        await tester.pumpAndSettle();
        expect(find.text('ОК'), findsNothing);
        expect(f.checks(kind), 0);
        expect(f.patch(kind), isNull);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$kind: PATCH contains only changed fields', (tester) async {
      final f = await _open(tester, kind);
      await tester.enterText(_field(data.$1), data.$3);
      await tester.pump();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(f.patch(kind), {data.$4: data.$5});
      expect(f.checks(kind), kind == 'payment' || kind == 'driver' ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('product: 600 ms debounce shares pending request with save', (
    tester,
  ) async {
    final f = await _open(tester, 'product');
    final gate = Completer<Product?>();
    f.products.gate = gate;
    await tester.enterText(_field('Название *'), 'Новое имя');
    await tester.pump(const Duration(milliseconds: 599));
    expect(f.products.checks, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(f.products.checks, 1);
    await tester.enterText(_field('Базовая цена *'), '200');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    expect(f.products.checks, 1);
    expect(f.products.patch, isNull);
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(f.products.patch, {'name': 'Новое имя', 'basePrice': 200.0});
    expect(f.products.checks, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('product: numeric formatting does not dirty form', (
    tester,
  ) async {
    final f = await _open(tester, 'product');
    await tester.enterText(_field('Базовая цена *'), '100,00');
    await tester.pump();
    expect(find.text('ОК'), findsOneWidget);
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();
    expect(f.products.patch, isNull);
  });
}
