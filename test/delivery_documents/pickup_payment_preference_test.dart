import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';

import 'anonymous_pickup_test.dart' show MemoryPickups;
import 'constructors_test.dart' as f;
import 'document_provider_test.dart' show Clients;

const cashId = '11111111-1111-4111-8111-111111111111';
const cardId = '22222222-2222-4222-8222-222222222222';
PaymentMethod method(String id, {bool active = true}) => PaymentMethod(
  id: id,
  name: id == cashId ? 'Cash' : 'Card',
  createdAt: DateTime(2026),
  isActive: active,
);

class Directory extends f.PaymentDirectory {
  List<PaymentMethod> rows = [method(cashId), method(cardId)];
  @override
  Future<List<PaymentMethod>> getAllPaymentMethods({
    bool includeDeactivated = false,
  }) async => rows;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  PickupConstructorProvider create({
    MemoryPickups? repo,
    Directory? directory,
  }) {
    final p = PickupConstructorProvider(
      pickupRepo: repo ?? MemoryPickups(),
      productRepo: f.Products(),
      paymentMethodRepo: directory ?? Directory(),
      clientRepo: Clients(),
    );
    addTearDown(p.dispose);
    p.resetForm();
    return p;
  }

  test('first launch stays empty; manual changes affect only later purchases and persist', () async {
    final p = create();
    await p.loadDirectories();
    p.addPurchase();
    expect(p.points.single.documentPaymentMethodId, isNull);
    expect(
      await p.selectPurchasePaymentMethod(
        p.points.first.viewId,
        method(cashId),
      ),
      isTrue,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(PickupConstructorProvider.lastPaymentMethodKey),
      cashId,
    );
    p.addPurchase();
    expect(p.points.last.documentPaymentMethodId, cashId);
    expect(p.points.last.documentPaymentMethodName, 'Cash');
    await p.selectPurchasePaymentMethod(p.points.last.viewId, method(cardId));
    p.addPurchase();
    p.addPurchase();
    expect(p.points.map((p) => p.documentPaymentMethodId), [
      cashId,
      cardId,
      cardId,
      cardId,
    ]);
    expect(
      prefs.getString(PickupConstructorProvider.lastPaymentMethodKey),
      cardId,
    );
    final restarted = create();
    await restarted.loadDirectories();
    restarted.addPurchase();
    expect(restarted.points.single.documentPaymentMethodId, cardId);
  });
  test('failed manual choices do not change preference', () async {
    final p = create();
    await p.loadDirectories();
    p.addPurchase();
    expect(
      await p.selectPurchasePaymentMethod('missing', method(cashId)),
      isFalse,
    );
    expect(
      await p.selectPurchasePaymentMethod(
        p.points.single.viewId,
        method(cardId, active: false),
      ),
      isFalse,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        PickupConstructorProvider.lastPaymentMethodKey,
      ),
      isNull,
    );
    p.addPurchase();
    expect(p.points.last.documentPaymentMethodId, isNull);
  });
  for (final absent in [true, false]) {
    test(
      'saved preference is ignored when ${absent ? 'missing' : 'inactive'}, including cached records',
      () async {
        SharedPreferences.setMockInitialValues({
          PickupConstructorProvider.lastPaymentMethodKey: cashId,
        });
        final directory = Directory();
        final p = create(directory: directory);
        await p.loadDirectories();
        directory.rows = absent ? [] : [method(cashId, active: false)];
        await p.loadDirectories();
        p.addPurchase();
        expect(p.points.single.documentPaymentMethodId, isNull);
        expect(
          (await SharedPreferences.getInstance()).getString(
            PickupConstructorProvider.lastPaymentMethodKey,
          ),
          cashId,
        );
      },
    );
  }
  test(
    'existing document keeps its payment; added purchase uses local preference',
    () async {
      final repo = MemoryPickups();
      final original = create(repo: repo);
      original.addPurchase();
      await original.selectPurchasePaymentMethod(
        original.points.single.viewId,
        method(cardId),
      );
      expect(await original.savePickup(), isTrue);
      SharedPreferences.setMockInitialValues({
        PickupConstructorProvider.lastPaymentMethodKey: cashId,
      });
      final p = create(repo: repo);
      await p.loadExistingPickupById('pickup');
      expect(p.points.single.documentPaymentMethodId, cardId);
      expect(
        (await SharedPreferences.getInstance()).getString(
          PickupConstructorProvider.lastPaymentMethodKey,
        ),
        cashId,
      );
      await p.beginEditing();
      p.addPurchase();
      expect(p.points.map((p) => p.documentPaymentMethodId), [cardId, cashId]);
      await p.selectPurchasePaymentMethod(
        p.points.first.viewId,
        method(cardId),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          PickupConstructorProvider.lastPaymentMethodKey,
        ),
        cardId,
      );
    },
  );
  test('delivery routes ignore pickup preference', () async {
    SharedPreferences.setMockInitialValues({
      PickupConstructorProvider.lastPaymentMethodKey: cashId,
    });
    final p = RouteConstructorProvider(
      carRepo: f.Cars(),
      driverRepo: f.Drivers(),
      routeRepo: f.Routes(),
      printService: f.PrintService(),
      productRepo: f.Products(),
      paymentMethodRepo: Directory(),
      clientRepo: Clients(),
    );
    addTearDown(p.dispose);
    p.resetForm();
    p.addClientPoint(
      Client(
        id: 'client',
        name: 'Client',
        phone: '',
        address: '',
        sleepingThresholdDays: 7,
        createdAt: DateTime(2026),
        isActive: true,
        defaultPaymentMethodId: cardId,
        defaultPaymentMethodName: 'Card',
      ),
    );
    expect(p.points.single.documentPaymentMethodId, cardId);
    expect(
      await p.selectPurchasePaymentMethod('missing', method(cardId)),
      isFalse,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        PickupConstructorProvider.lastPaymentMethodKey,
      ),
      cashId,
    );
  });
}
