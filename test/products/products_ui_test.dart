import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/products/ui/product_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/points_dialogs.dart';

class _Clients implements ClientRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Payments implements PaymentMethodRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _product(String id, String name, {bool active = true}) => Product(
  id: id,
  name: name,
  basePrice: 100,
  createdAt: DateTime.utc(2026),
  isActive: active,
);

class _Products implements ProductRepository {
  List<Product> rows = [
    _product('active', 'Вода'),
    _product('inactive', 'Стаканы', active: false),
  ];
  Product? duplicate;
  int creates = 0;
  int patches = 0;
  Completer<List<Product>>? loadGate;

  @override
  Future<List<Product>> getAvailableProducts({
    bool includeDeactivated = false,
  }) async {
    if (loadGate != null) return loadGate!.future;
    return rows.where((row) => includeDeactivated || row.isActive).toList();
  }

  @override
  Future<Product?> checkDuplicate(String name) async => duplicate;

  @override
  Future<Product> createProduct(CreateProductRequest request) async {
    creates++;
    final result = _product('created', request.name);
    rows.add(result);
    return result;
  }

  @override
  Future<Product> updateProduct(String id, UpdateProductRequest request) async {
    patches++;
    final old = rows.firstWhere((row) => row.id == id);
    final result = Product(
      id: id,
      name: request.name ?? old.name,
      basePrice: request.basePrice ?? old.basePrice,
      createdAt: old.createdAt,
      isActive: request.isActive ?? old.isActive,
    );
    rows = rows.map((row) => row.id == id ? result : row).toList();
    return result;
  }

  @override
  Future<Product> getProductById(String id) async =>
      rows.firstWhere((row) => row.id == id);
}

class _Orders extends OrderPointsProvider {
  _Orders(_Products products)
    : super(
        productRepo: products,
        paymentMethodRepo: _Payments(),
        clientRepo: _Clients(),
      ) {
    this.products = products.rows.where((row) => row.isActive).toList();
    points = [
      const RoutePoint(
        clientId: '1',
        clientName: 'Клиент',
        city: 'Город',
        address: 'Адрес',
        phone: '123',
        salesRepresentative: '',
        items: [],
      ),
    ];
  }
}

Future<void> _open(
  WidgetTester tester,
  _Orders provider, {
  bool editor = false,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.createTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              if (editor) {
                showDialog<Product>(
                  context: context,
                  builder: (_) => ProductDialog(provider: provider),
                );
              } else {
                TaskDialogs.showAddTask(context, provider, 0);
              }
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('eye edit add remain in order while unselected and loading', (
    tester,
  ) async {
    final repo = _Products();
    final provider = _Orders(repo);
    await _open(tester, provider);
    final eye = find.byTooltip('Показать неактивные записи');
    final edit = find.byTooltip('Редактировать выбранный элемент');
    final create = find.byTooltip('Добавить Продукция / услуга');
    expect(tester.getCenter(eye).dx, lessThan(tester.getCenter(edit).dx));
    expect(tester.getCenter(edit).dx, lessThan(tester.getCenter(create).dx));
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Редактировать выбранный элемент',
            ),
          )
          .onPressed,
      isNull,
    );
    repo.loadGate = Completer<List<Product>>();
    await tester.tap(eye);
    await tester.pump();
    expect(find.byTooltip('Показать неактивные записи'), findsOneWidget);
    expect(edit, findsOneWidget);
    expect(create, findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Показать неактивные записи',
            ),
          )
          .onPressed,
      isNull,
    );
    repo.loadGate!.complete(repo.rows);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Скрыть неактивные записи'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_inactive_products'), isTrue);
  });

  testWidgets(
    'inactive choice confirms activation and cancel restores selection',
    (tester) async {
      final repo = _Products();
      final provider = _Orders(repo);
      await _open(tester, provider);
      await tester.tap(find.byTooltip('Показать неактивные записи'));
      await tester.pumpAndSettle();
      Future<void> chooseInactive() async {
        await tester.tap(find.byType(DropdownButtonFormField<Product>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Стаканы').last);
        await tester.pumpAndSettle();
      }

      await chooseInactive();
      expect(find.text('Товар неактивен'), findsOneWidget);
      await tester.tap(find.text('Отмена').last);
      await tester.pumpAndSettle();
      expect(repo.patches, 0);
      expect(
        tester
            .widget<DropdownButtonFormField<Product>>(
              find.byType(DropdownButtonFormField<Product>),
            )
            .initialValue,
        isNull,
      );
      await chooseInactive();
      await tester.tap(find.text('Активировать и выбрать'));
      await tester.pumpAndSettle();
      expect(repo.patches, 1);
      final selected = tester
          .widget<DropdownButtonFormField<Product>>(
            find.byType(DropdownButtonFormField<Product>),
          )
          .initialValue;
      expect(selected?.id, 'inactive');
      expect(selected?.isActive, isTrue);
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(provider.points.single.items.single.productId, 'inactive');
    },
  );

  testWidgets('similar name can be created', (tester) async {
    final repo = _Products()..duplicate = _product('active', 'Вода');
    await _open(tester, _Orders(repo), editor: true);
    await tester.enterText(find.byType(TextFormField).at(0), 'Вода большая');
    await tester.enterText(find.byType(TextFormField).at(1), '200');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(repo.rows.last.name, 'Вода большая');
    expect(find.byType(ProductDialog), findsNothing);
  });

  testWidgets(
    'existing match can be selected and deactivation clears selection',
    (tester) async {
      final repo = _Products()..duplicate = _product('active', 'Вода');
      final provider = _Orders(repo);
      await _open(tester, provider);
      await tester.tap(find.byTooltip('Добавить Продукция / услуга'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Вода');
      await tester.enterText(find.byType(TextFormField).at(1), '200');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Найден похожий товар:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выбрать для задания'));
      await tester.pumpAndSettle();
      expect(repo.creates, 0);
      expect(
        tester
            .widget<DropdownButtonFormField<Product>>(
              find.byType(DropdownButtonFormField<Product>),
            )
            .initialValue
            ?.id,
        'active',
      );
      await tester.tap(find.byTooltip('Редактировать выбранный элемент'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Деактивировать товар'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Деактивировать'));
      await tester.pumpAndSettle();
      expect(repo.rows.first.isActive, isFalse);
      expect(
        tester
            .widget<DropdownButtonFormField<Product>>(
              find.byType(DropdownButtonFormField<Product>),
            )
            .initialValue,
        isNull,
      );
      expect(find.byTooltip('Редактировать выбранный элемент'), findsOneWidget);
      expect(find.byTooltip('Добавить Продукция / услуга'), findsOneWidget);
    },
  );

  testWidgets('exact name stays in editor without creating duplicate', (
    tester,
  ) async {
    final repo = _Products()..duplicate = _product('active', 'Вода');
    await _open(tester, _Orders(repo), editor: true);
    await tester.enterText(find.byType(TextFormField).at(0), 'Вода');
    await tester.enterText(find.byType(TextFormField).at(1), '200');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(repo.creates, 0);
    expect(find.byType(ProductDialog), findsOneWidget);
    expect(
      find.textContaining('Товар с таким названием уже существует.'),
      findsOneWidget,
    );
  });
}
