import 'dart:async';

import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_document_api.dart';
import 'package:mountain_fairytale/features/delivery_route/data/document_money.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';

class Clients implements ClientRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Payments implements PaymentMethodRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Catalog implements ProductRepository {
  double price = 10;
  String name = 'Товар';
  bool active = true;
  @override
  Future<Product> getProductById(String id) async => Product(
    id: id,
    name: name,
    basePrice: price,
    createdAt: DateTime(2026),
    isActive: active,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Locks implements DocumentLockRepository {
  Object? connectionError;
  Object? acquireError;
  @override
  Future<void> checkConnection() async {
    if (connectionError != null) throw connectionError!;
  }

  int acquired = 0, renewed = 0, released = 0;
  bool failRenew = false, failRelease = false;
  Completer<String>? acquireGate;
  @override
  Future<String> acquireEditLock(String id) async {
    acquired++;
    if (acquireError != null) throw acquireError!;
    return acquireGate == null ? 'manager' : acquireGate!.future;
  }

  @override
  Future<String> renewEditLock(String id) async {
    renewed++;
    if (failRenew) {
      throw const ApiException(statusCode: 409, message: 'Expired');
    }
    return 'manager';
  }

  @override
  Future<void> releaseEditLock(String id) async {
    released++;
    if (failRelease) throw StateError('Offline');
  }
}

const item = DeliveryTaskItem(
  productId: 'product',
  productName: 'Товар',
  quantity: 2,
  price: 1.005,
);
const point = RoutePoint(
  pointId: 'point',
  clientId: 'client',
  clientName: 'Клиент',
  address: 'Адрес',
  phone: '123',
  salesRepresentative: '',
  items: [item],
);

class Orders extends OrderPointsProvider {
  RouteDocument? recoveryDocument;
  @override
  Future<RouteDocument?> readRecoveryDocument() async => recoveryDocument;
  @override
  Future<RouteDocument?> findPendingCreation(String requestId) async =>
      recoveryDocument;
  @override
  Future<void> applyRecoveryDocument(RouteDocument document) async {
    final sheet = document as PickupSheet;
    points = sheet.points;
    documentId = sheet.id;
    documentRevision = sheet.revision;
    documentActive = sheet.isActive;
  }

  int refreshes = 0;
  bool failRead = false;
  Orders(Catalog catalog, Locks locks)
    : super(
        productRepo: catalog,
        clientRepo: Clients(),
        paymentMethodRepo: Payments(),
        lockRepository: locks,
      );
  @override
  Future<void> refreshForEditing() async {
    refreshes++;
    if (failRead) throw StateError('Read failed');
  }
}

void main() {
  late Catalog catalog;
  late Locks locks;
  late Orders provider;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    catalog = Catalog();
    locks = Locks();
    provider = Orders(catalog, locks);
    provider.points = [point];
  });
  tearDown(() => provider.dispose());
  test(
    'selected name survives catalog rename, edits and request serialization',
    () async {
      catalog.name = 'Новое имя каталога';
      catalog.price = 30;
      expect(
        await provider.addCurrentProduct(
          0,
          'second',
          3,
          productName: '  Вода Горная  ',
        ),
        isTrue,
      );
      final added = provider.points.single.items.last;
      expect(added.productName, '  Вода Горная  ');
      expect(added.price, 30);
      provider.updateTaskQuantity(0, 1, 4);
      catalog.name = 'Ещё одно имя каталога';
      catalog.price = 40;
      expect(
        provider.replaceItemPrice(
          provider.points.single,
          provider.points.single.items.last,
          await catalog.getProductById('second'),
        ),
        isTrue,
      );
      expect(provider.points.single.items.last.toRequestJson(), {
        'productId': 'second',
        'productName': '  Вода Горная  ',
        'quantity': 4,
        'price': 40.0,
      });
      expect(
        DeliveryTaskItem.fromJson(item.toJson()).toRequestJson()['productName'],
        'Товар',
      );
      provider.removeTaskFromPoint(0, 1);
      expect(
        await provider.addCurrentProduct(
          0,
          'second',
          1,
          productName: catalog.name,
        ),
        isTrue,
      );
      expect(
        provider.points.single.items.last.productName,
        'Ещё одно имя каталога',
      );
    },
  );
  test('HALF_UP rounds each row before point/document sums', () {
    expect(lineAmountCents(1, 1.005), 101);
    expect(lineAmountCents(3, 1.005), 302);
    expect(lineAmountCents(1, 2.675), 268);
    expect(lineAmountCents(3, 0.1), 30);
    expect(lineAmountCents(1, 0), 0);
    expect(lineAmountCents(1000000, 1e-6), 100);
    provider.points = [
      point.copyWith(items: [item, item]),
    ];
    expect(provider.grandTotal, 4.02);
  });
  test('point identity survives edits and duplicate addition leaves quantity and price unchanged', () async {
    final product = await catalog.getProductById('product');
    provider.addTaskToPoint(0, product, 5);
    expect(provider.points.single.items.single, same(item));
    provider.updateTaskQuantity(0, 0, 4);
    expect(provider.points.single.pointId, 'point');
    expect(provider.points.single.items.single.quantity, 4);
    expect(provider.points.single.items.single.price, 1.005);
    provider.removeTaskFromPoint(0, 0);
    expect(provider.points.single.pointId, 'point');
    expect(provider.points.single.items, isEmpty);
  });
  test('new rows fetch current price; explicit refresh preserves quantity and rejects inactive products', () async {
    catalog.price = 15;
    expect(
      await provider.addCurrentProduct(0, 'second', 3, productName: 'Товар'),
      isTrue,
    );
    expect(provider.points.single.items.last.price, 15);
    catalog.price = 25;
    expect(
      await provider.addCurrentProduct(0, 'second', 7, productName: 'Товар'),
      isFalse,
    );
    expect(provider.points.single.items.last.quantity, 3);
    expect(provider.points.single.items.last.price, 15);
    final target = provider.points.single;
    final old = target.items.last;
    expect(
      provider.replaceItemPrice(
        target,
        old,
        await catalog.getProductById('second'),
      ),
      isTrue,
    );
    expect(provider.points.single.items.last.price, 25);
    expect(provider.points.single.items.last.quantity, 3);
    catalog.active = false;
    final inactive = await catalog.getProductById('second');
    expect(
      provider.replaceItemPrice(
        provider.points.single,
        provider.points.single.items.last,
        inactive,
      ),
      isFalse,
    );
    expect(
      await provider.addCurrentProduct(0, 'third', 1, productName: 'Товар'),
      isFalse,
    );
  });
  test(
    'reading never acquires a lock and cancelled documents cannot edit',
    () async {
      provider.initializeDocumentSession(id: 'document', active: false);
      expect(provider.canSave, isFalse);
      expect(await provider.beginEditing(), isFalse);
      expect(locks.acquired, 0);
      expect(await provider.closeDocument(), isTrue);
      expect(locks.released, 0);
    },
  );
  testWidgets(
    'heartbeat every 30 seconds; loss disables save, reacquisition preserves draft',
    (tester) async {
      provider.initializeDocumentSession(id: 'document');
      expect(locks.acquired, 0);
      expect(await provider.beginEditing(), isTrue);
      expect(provider.canSave, isTrue);
      expect(provider.refreshes, 1);
      await tester.pump(const Duration(seconds: 29));
      expect(locks.renewed, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(locks.renewed, 1);
      provider.updateTaskQuantity(0, 0, 5);
      locks.failRenew = true;
      await tester.pump(const Duration(seconds: 30));
      expect(provider.canSave, isFalse);
      expect(provider.connectionInterrupted, isTrue);
      expect(provider.isEditing, isTrue);
      locks.failRenew = false;
      expect(await provider.beginEditing(), isTrue);
      expect(provider.refreshes, 1);
      expect(provider.points.single.items.single.quantity, 5);
      expect(await provider.closeDocument(), isTrue);
      expect(locks.released, 1);
      await tester.pump(const Duration(minutes: 3));
      expect(locks.renewed, 2);
    },
  );
  testWidgets(
    'cancel releases lock, stops heartbeat and refreshes again on next edit',
    (tester) async {
      provider.initializeDocumentSession(id: 'document');
      expect(await provider.beginEditing(), isTrue);
      expect(await provider.cancelEditing(), isTrue);
      expect(provider.isEditing, isFalse);
      expect(provider.canSave, isFalse);
      expect(locks.released, 1);
      await tester.pump(const Duration(seconds: 60));
      expect(locks.renewed, 0);
      expect(await provider.beginEditing(), isTrue);
      expect(provider.refreshes, 3);
      expect(locks.acquired, 2);
      await provider.closeDocument();
    },
  );
  test('failed cancel keeps editing available and allows retry', () async {
    provider.initializeDocumentSession(id: 'document');
    await provider.beginEditing();
    provider.updateTaskQuantity(0, 0, 9);
    provider.failRead = true;
    expect(await provider.cancelEditing(), isFalse);
    expect(provider.isEditing, isTrue);
    expect(provider.points.single.items.single.quantity, 9);
    expect(locks.released, 0);
    expect(
      provider.documentError,
      contains('Не удалось отменить редактирование'),
    );
    provider.failRead = false;
    locks.failRelease = true;
    expect(await provider.cancelEditing(), isFalse);
    expect(provider.isEditing, isTrue);
    locks.failRelease = false;
    expect(await provider.cancelEditing(), isTrue);
    expect(provider.documentError, isNull);
    await provider.closeDocument();
  });
  test('failed post-lock read still releases lock on exit', () async {
    provider.initializeDocumentSession(id: 'document');
    provider.failRead = true;
    expect(await provider.beginEditing(), isFalse);
    expect(await provider.closeDocument(), isTrue);
    expect(locks.released, 1);
  });
  test(
    'close while acquisition is in flight never leaves an active heartbeat',
    () async {
      provider.initializeDocumentSession(id: 'document');
      locks.acquireGate = Completer<String>();
      final acquiring = provider.beginEditing();
      final closing = provider.closeDocument();
      locks.acquireGate!.complete('manager');
      expect(await acquiring, isFalse);
      expect(await closing, isTrue);
      expect(provider.canSave, isFalse);
      expect(locks.released, greaterThanOrEqualTo(1));
    },
  );
}
