import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_dialog.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_selector.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';

PaymentMethod _method(String id, String name, {bool active = true}) =>
    PaymentMethod(
      id: id,
      name: name,
      createdAt: DateTime(2026),
      isActive: active,
    );

class _Payments implements PaymentMethodRepository {
  List<PaymentMethod> rows = [
    _method('active', 'Наличные'),
    _method('inactive', 'Карта', active: false),
  ];
  PaymentMethod? duplicate;
  bool conflict = false;
  bool duplicateFailure = false;
  int creates = 0;
  int patches = 0;
  @override
  Future<List<PaymentMethod>> getAllPaymentMethods({
    bool includeDeactivated = false,
  }) async => rows.where((row) => includeDeactivated || row.isActive).toList();
  @override
  Future<PaymentMethod> getPaymentMethodById(String id) async =>
      rows.firstWhere((row) => row.id == id);
  @override
  Future<PaymentMethod?> checkDuplicate(String name) async {
    if (duplicateFailure) throw Exception('offline');
    return duplicate;
  }

  @override
  Future<PaymentMethod> createPaymentMethod(
    CreatePaymentMethodRequest request,
  ) async {
    creates++;
    if (conflict) {
      throw const ApiException(statusCode: 409, message: 'Duplicate');
    }
    final created = _method('created', request.name);
    rows.add(created);
    return created;
  }

  @override
  Future<PaymentMethod> updatePaymentMethod(
    String id,
    UpdatePaymentMethodRequest request,
  ) async {
    patches++;
    final old = await getPaymentMethodById(id);
    final updated = _method(
      id,
      request.name ?? old.name,
      active: request.isActive ?? old.isActive,
    );
    rows = rows.map((row) => row.id == id ? updated : row).toList();
    return updated;
  }
}

class _Clients implements ClientRepository {
  UpdateClientRequest? request;
  bool fail = false;
  @override
  Future<Client> updateClient(int id, UpdateClientRequest request) async {
    if (fail) throw Exception('offline');
    this.request = request;
    return Client(
      id: id,
      name: 'Клиент',
      phone: '123',
      address: 'Адрес',
      sleepingThresholdDays: 7,
      defaultPaymentMethodId: request.defaultPaymentMethodId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Products implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Orders extends OrderPointsProvider {
  _Orders(_Payments payments, _Clients clients)
    : super(
        paymentMethodRepo: payments,
        clientRepo: clients,
        productRepo: _Products(),
      ) {
    paymentMethods = payments.rows.where((row) => row.isActive).toList();
    for (final row in payments.rows) {
      paymentMethodsById[row.id] = row;
    }
    addClientPoint(
      const Client(
        id: 1,
        name: 'Клиент',
        phone: '123',
        address: 'Адрес',
        sleepingThresholdDays: 7,
        defaultPaymentMethodId: 'active',
        defaultPaymentMethod: 'Наличные',
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _Orders orders,
  _Clients clients, {
  bool editor = false,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final clientsProvider = ClientsProvider(clients);
  addTearDown(clientsProvider.dispose);
  addTearDown(orders.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.createTheme(Brightness.light),
      home: Scaffold(
        body: editor
            ? PaymentMethodDialog(provider: orders)
            : ListenableBuilder(
                listenable: orders,
                builder: (context, _) => PaymentMethodSelector(
                  provider: orders,
                  clientsProvider: clientsProvider,
                  clientId: 1,
                  selectedId: orders.points.single.paymentMethodId,
                  selectedName: orders.points.single.paymentMethod,
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'similar name and unavailable duplicate hint do not prevent saving',
    (tester) async {
      final repo = _Payments()..duplicateFailure = true;
      final clients = _Clients();
      final orders = _Orders(repo, clients);
      await _open(tester, orders, clients);
      await tester.tap(find.byTooltip('Добавить Форма оплаты *'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Наличные новые');
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(orders.points.single.paymentMethodId, 'created');
      expect(clients.request!.defaultPaymentMethodId, 'created');
      expect(clients.request!.defaultPaymentMethod, isNull);
    },
  );

  testWidgets('server fuzzy match is advisory and similar name is saved', (
    tester,
  ) async {
    final repo = _Payments()..duplicate = _method('active', 'Наличные');
    final clients = _Clients();
    final orders = _Orders(repo, clients);
    await _open(tester, orders, clients);
    await tester.tap(find.byTooltip('Добавить Форма оплаты *'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Наличные новые');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(orders.points.single.paymentMethod, 'Наличные новые');
  });

  testWidgets('409 leaves editor open and shows a conflict', (tester) async {
    final repo = _Payments()..conflict = true;
    final clients = _Clients();
    await _open(tester, _Orders(repo, clients), clients, editor: true);
    await tester.enterText(find.byType(TextFormField), 'Наличные');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentMethodDialog), findsOneWidget);
    expect(
      find.text('Способ оплаты с таким названием уже существует.'),
      findsOneWidget,
    );
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(
      field.forceErrorText,
      'Способ оплаты с таким названием уже существует.',
    );
    expect(
      tester.state<FormFieldState<String>>(find.byType(TextFormField)).hasError,
      isTrue,
    );
    expect(
      find.ancestor(
        of: find.text('Способ оплаты с таким названием уже существует.'),
        matching: find.byType(TextFormField),
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'Другое название');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).forceErrorText,
      isNull,
    );
    expect(
      tester.state<FormFieldState<String>>(find.byType(TextFormField)).hasError,
      isFalse,
    );
  });

  testWidgets(
    'inactive selection cancels safely, then activates and saves UUID',
    (tester) async {
      final repo = _Payments();
      final clients = _Clients();
      final orders = _Orders(repo, clients);
      await _open(tester, orders, clients);
      final eye = find.byTooltip('Показать неактивные записи');
      final edit = find.byTooltip('Редактировать выбранный элемент');
      final add = find.byTooltip('Добавить Форма оплаты *');
      expect(tester.getCenter(eye).dx, lessThan(tester.getCenter(edit).dx));
      expect(tester.getCenter(edit).dx, lessThan(tester.getCenter(add).dx));
      await tester.tap(eye);
      await tester.pumpAndSettle();
      Future<void> chooseInactive() async {
        await tester.tap(find.byType(DropdownButtonFormField<PaymentMethod>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Карта — Неактивен').last);
        await tester.pumpAndSettle();
      }

      await chooseInactive();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(orders.points.single.paymentMethodId, 'active');
      expect(repo.patches, 0);
      await chooseInactive();
      await tester.tap(find.text('Активировать и выбрать'));
      await tester.pumpAndSettle();
      expect(repo.patches, 1);
      expect(clients.request!.defaultPaymentMethodId, 'inactive');
      expect(orders.points.single.paymentMethodId, 'inactive');
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'show_inactive_payment_methods',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'deactivation retains current client reference and displayed name',
    (tester) async {
      final repo = _Payments();
      final clients = _Clients();
      final orders = _Orders(repo, clients);
      await _open(tester, orders, clients);
      await tester.tap(find.byTooltip('Редактировать выбранный элемент'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Деактивировать способ оплаты'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Деактивировать'));
      await tester.pumpAndSettle();
      expect(orders.points.single.paymentMethodId, 'active');
      expect(orders.paymentMethods, isEmpty);
      expect(find.text('Наличные — Неактивен'), findsOneWidget);
      expect(clients.request, isNull);
    },
  );

  testWidgets(
    'filter hides current inactive method from options without clearing client',
    (tester) async {
      final repo = _Payments();
      final clients = _Clients();
      final orders = _Orders(repo, clients);
      // Keep another active option so the closed field and menu can both be checked.
      repo.rows.add(_method('second', 'СБП'));
      await orders.loadPaymentMethods();
      await orders.setPaymentMethodActive('active', false);
      await _open(tester, orders, clients);
      DropdownButtonFormField<PaymentMethod> dropdown() =>
          tester.widget<DropdownButtonFormField<PaymentMethod>>(
            find.byType(DropdownButtonFormField<PaymentMethod>),
          );
      expect(
        tester
            .widget<DropdownButton<PaymentMethod>>(
              find.byType(DropdownButton<PaymentMethod>),
            )
            .items!
            .map((item) => item.value!.id),
        ['second'],
      );
      expect(dropdown().initialValue, isNull);
      expect(find.text('Наличные — Неактивен'), findsOneWidget);
      await tester.tap(find.byTooltip('Показать неактивные записи'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<PaymentMethod>>(
              find.byType(DropdownButton<PaymentMethod>),
            )
            .items!
            .map((item) => item.value!.id),
        containsAll(['active', 'inactive', 'second']),
      );
      expect(dropdown().initialValue?.id, 'active');
      await tester.tap(find.byTooltip('Скрыть неактивные записи'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<PaymentMethod>>(
              find.byType(DropdownButton<PaymentMethod>),
            )
            .items!
            .map((item) => item.value!.id),
        ['second'],
      );
      expect(dropdown().initialValue, isNull);
      expect(find.text('Наличные — Неактивен'), findsOneWidget);
      expect(orders.points.single.paymentMethodId, 'active');
      expect(clients.request, isNull);
    },
  );

  testWidgets('client save failure preserves previous selection', (
    tester,
  ) async {
    final repo = _Payments()..rows.add(_method('second', 'СБП'));
    final clients = _Clients()..fail = true;
    final orders = _Orders(repo, clients);
    await _open(tester, orders, clients);
    await tester.tap(find.byType(DropdownButtonFormField<PaymentMethod>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('СБП').last);
    await tester.pumpAndSettle();
    expect(orders.points.single.paymentMethodId, 'active');
    expect(
      find.textContaining('Не удалось сохранить способ оплаты клиента'),
      findsOneWidget,
    );
  });
}
