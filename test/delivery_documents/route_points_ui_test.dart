import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_points_list.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/point_representative_selector.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';

import 'document_provider_test.dart'
    show Orders, Catalog, Locks, Clients, point;

class RepresentativeClients extends Clients {
  UpdateClientRequest? request;
  bool fail = false;
  @override
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives({
    bool includeDeactivated = false,
  }) async => [
    const ClientDirectoryEntry('rep', 'Иванов Алексей'),
  ];
  @override
  Future<Client> updateClient(String id, UpdateClientRequest request) async {
    if (fail) throw StateError('offline');
    this.request = request;
    return Client(
      id: id,
      name: 'Клиент',
      phone: '123',
      address: 'Адрес',
      sleepingThresholdDays: 7,
      createdAt: DateTime(2026),
      isActive: true,
      salesRepresentativeId: request.salesRepresentativeId as String?,
      salesRepresentativeName: 'Иванов Алексей',
    );
  }
}

class Payments implements PaymentMethodRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RepresentativeOrders extends OrderPointsProvider {
  RepresentativeOrders(ClientRepository clients)
    : super(
        clientRepo: clients,
        productRepo: Catalog(),
        paymentMethodRepo: Payments(),
      );
}

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('route summary and quantity controls work at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final orders = Orders(Catalog(), Locks())
        ..points = [point]
        ..isEditing = false;
      final clients = ClientsProvider(Clients());
      addTearDown(orders.dispose);
      addTearDown(clients.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: clients,
          child: MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: orders,
                builder: (_, _) => RoutePointsList(provider: orders),
              ),
            ),
          ),
        ),
      );
      expect(find.text('2.01 ₽'), findsOneWidget);
      expect(find.textContaining('1 позиция'), findsOneWidget);
      expect(find.text('Товар'), findsNothing);
      final amountPosition = tester.getTopLeft(find.text('2.01 ₽'));
      for (final payment in ['Нал', 'Безналичная оплата по расчётному счёту']) {
        orders.points = [
          RoutePoint.fromJson({
            ...point.toJson(),
            'defaultPaymentMethodName': payment,
          }),
        ];
        orders.notifyListeners();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('2.01 ₽')), amountPosition);
        expect(find.textContaining(payment), findsOneWidget);
      }
      await tester.tap(find.text('Клиент'));
      await tester.pumpAndSettle();
      expect(find.text('Телефон: 123'), findsOneWidget);
      expect(
        find.widgetWithText(AppSecondaryButton, 'Добавить позицию'),
        findsOneWidget,
      );
      orders.isEditing = true;
      orders.notifyListeners();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Увеличить количество'));
      await tester.tap(find.byTooltip('Увеличить количество'));
      await tester.pump();
      expect(orders.points.single.items.single.quantity, 3);
      expect(find.text('3.02 ₽'), findsWidgets);
      await tester.tap(find.byTooltip('Уменьшить количество'));
      await tester.pump();
      await tester.tap(find.byTooltip('Уменьшить количество'));
      await tester.pump();
      expect(orders.points.single.items.single.quantity, 1);
      final minus = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Уменьшить количество',
        ),
      );
      expect(minus.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'representative saves client UUID and preserves order; failure retains selection',
    (tester) async {
      final repo = RepresentativeClients();
      final orders = RepresentativeOrders(repo)..points = [point];
      final clients = ClientsProvider(repo);
      addTearDown(orders.dispose);
      addTearDown(clients.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: clients,
          child: MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: orders,
                builder: (_, _) => PointRepresentativeSelector(
                  provider: orders,
                  point: orders.points.single,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<ClientDirectoryEntry>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Иванов Алексей').last);
      await tester.pumpAndSettle();
      expect(repo.request!.toJson(), {'salesRepresentativeId': 'rep'});
      expect(orders.points.single.salesRepresentativeId, 'rep');
      expect(orders.points.single.items, point.items);
      expect(orders.points.single.totalCents, point.totalCents);
      repo.fail = true;
      await tester.tap(
        find.byType(DropdownButtonFormField<ClientDirectoryEntry>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Иванов Алексей').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Не удалось сохранить представителя'),
        findsOneWidget,
      );
      expect(orders.points.single.salesRepresentativeId, 'rep');
      expect(tester.takeException(), isNull);
    },
  );
}
