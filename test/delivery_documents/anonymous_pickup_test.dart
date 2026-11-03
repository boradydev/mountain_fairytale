import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_screen.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_selector.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_selection_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/point_representative_selector.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';

import 'constructors_test.dart' show Products, PaymentDirectory;
import 'document_provider_test.dart' show Clients;

class MemoryPickups implements PickupRepository {
  PickupSheet? sheet;
  @override
  Future<PickupSheet> savePickupSheet(PickupSheet value) async {
    sheet = PickupSheet.fromJson({
      ...value.toJson(),
      'deliveryDocumentId': 'pickup',
      'points': [
        for (final (index, point) in value.points.indexed)
          {
            ...point.toJson(),
            'pointId': point.pointId ?? 'point-$index',
            'position': index,
          },
      ],
    });
    return sheet!;
  }

  @override
  Future<PickupSheet> getPickupSheetById(String id) async => sheet!;
  @override
  Future<String> acquireEditLock(String id) async => 'manager';
  @override
  Future<String> renewEditLock(String id) async => 'manager';
  @override
  Future<void> releaseEditLock(String id) async {}
  @override
  Future<void> checkConnection() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PickupConstructorProvider pickupProvider(MemoryPickups repo) =>
    PickupConstructorProvider(
      pickupRepo: repo,
      productRepo: Products(),
      paymentMethodRepo: PaymentDirectory(),
      clientRepo:
          Clients(), // Any attempt to access clients throws in this fake.
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('anonymous purchases keep independent identity, payment and goods through save/edit/cancel', () async {
    final repo = MemoryPickups();
    final p = pickupProvider(repo)..resetForm();
    addTearDown(p.dispose);
    p.addPurchase();
    p.addPurchase();
    final first = p.points.first.viewId;
    final second = p.points.last.viewId;
    expect(first, isNot(second));
    expect(p.points.every((point) => point.clientId == null), isTrue);
    final cash = PaymentMethod(
      id: 'cash',
      name: 'Наличные',
      createdAt: DateTime(2026),
      isActive: true,
    );
    final card = PaymentMethod(
      id: 'card',
      name: 'Карта',
      createdAt: DateTime(2026),
      isActive: true,
    );
    expect(await p.selectPurchasePaymentMethod(first, cash), isTrue);
    expect(await p.selectPurchasePaymentMethod(second, card), isTrue);
    final product = await Products().getProductById('product');
    p.addTaskToPoint(0, product, 2);
    p.updateTaskQuantity(0, 0, 3);
    expect(p.points.first.viewId, first);
    expect(p.points.last.viewId, second);
    p.reorderPoints(0, 2);
    expect(p.points.map((point) => point.viewId), [first, second]);
    expect(await p.savePickup(), isTrue);
    expect(p.points.map((point) => point.documentPaymentMethodId), [
      'cash',
      'card',
    ]);
    expect(p.points.first.items.single.quantity, 3);
    await p.beginEditing();
    p.removePoint(0);
    p.addPurchase();
    expect(p.points.first.pointId, 'point-1');
    await p.cancelEditing();
    expect(p.points.map((point) => point.pointId), ['point-0', 'point-1']);
    expect(p.points.first.documentPaymentMethodId, 'cash');
    final restored = RoutePoint.fromJson(p.points.first.toJson());
    expect(restored.clientId, isNull);
    expect(restored.toRequestJson(creating: false)['clientId'], isNull);
  });

  testWidgets(
    'pickup adds several purchases without client panel, representative or drag handles',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = pickupProvider(MemoryPickups());
      final theme = ThemeProvider(await SharedPreferences.getInstance());
      addTearDown(p.dispose);
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: p),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: const MaterialApp(home: PickupConstructorScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ClientSelectionPanel), findsNothing);
      await tester.tap(find.text('Добавить покупку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить покупку'));
      await tester.pumpAndSettle();
      expect(find.text('Покупка 1'), findsOneWidget);
      expect(find.text('Покупка 2'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      await tester.tap(find.text('Покупка 1'));
      await tester.pumpAndSettle();
      expect(find.byType(PointRepresentativeSelector), findsNothing);
      expect(find.byType(PaymentMethodSelector), findsOneWidget);
      expect(find.text('Добавить позицию'), findsOneWidget);
      expect(find.textContaining('Телефон:'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
