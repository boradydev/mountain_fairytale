import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/data/client_latest_order.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_card_content.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/client_last_order.dart';
import 'package:mountain_fairytale/features/clients/ui/client_list.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:provider/provider.dart';

import 'clients_ui_test.dart' show ClientsFake;

Client customer({
  ClientLastOrder? order,
  DateTime? cooldown,
  DateTime? latest,
}) => Client(
  id: 'customer',
  name: 'Клиент',
  phone: '+79123456789',
  address: 'Адрес',
  sleepingThresholdDays: 10,
  createdAt: DateTime(2026),
  isActive: true,
  lastOrder: order,
  latestOrderCreatedAt: DateTime(2026, 11, 5, 15, 45),
  latestOrderPlannedDate: latest,
  cooldownUntil: cooldown,
);

ClientLastOrder order(DateTime date, {List<String> types = const ['pickup']}) =>
    ClientLastOrder(
      date: date,
      fulfillmentTypes: types,
      items: const [
        ClientOrderItem(productId: '1', productName: 'Вода 19 л', quantity: 2),
        ClientOrderItem(productId: '2', productName: 'Помпа', quantity: 1),
        ClientOrderItem(productId: '3', productName: 'Стаканы', quantity: 10),
        ClientOrderItem(productId: '4', productName: 'Чехол', quantity: 1),
      ],
    );

ClientLatestOrder detail({int count = 4}) => ClientLatestOrder.fromJson({
  'deliveryDocumentId': 'document',
  'pointId': 'point',
  'createdAt': '2026-11-05T15:45:00',
  'plannedDate': '2026-11-07',
  'totalAmount': '${count * 12.35}',
  'items': List.generate(
    count,
    (i) => {
      'itemId': 'item-$i',
      'productId': 'product-$i',
      'productName': 'Товар $i',
      'quantity': 1,
      'price': '12.345',
      'amount': '12.35',
      'isFreePrice': true,
      'driverNote':
          'Полное примечание строки $i с длинным текстом для водителя',
    },
  ),
});

void main() {
  test('order response round trips and elapsed days use calendar dates', () {
    final original = customer(
      order: order(DateTime(2026, 10, 18), types: ['delivery', 'pickup']),
    );
    final decoded = Client.fromJson(original.toJson());
    expect(decoded.lastOrder!.toJson(), original.lastOrder!.toJson());
    expect(decoded.lastOrder!.fulfillmentLabel, 'Доставка и самовывоз');
    expect(decoded.daysSinceLastOrder(DateTime(2026, 10, 19, 0, 1)), 1);
    expect(customer().daysSinceLastOrder(DateTime(2026, 10, 19)), isNull);
  });

  for (final size in [const Size(420, 900), const Size(1200, 900)]) {
    testWidgets(
      'compact preview, lazy read-only dialog and separate actions at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var edits = 0;
        var requests = 0;
        final pending = Completer<ClientLatestOrder?>();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.createTheme(Brightness.light),
            home: Scaffold(
              body: AppBaseCard(
                onTap: () => edits++,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Имя клиента'),
                    ClientLastOrderView(
                      client: customer(
                        order: order(DateTime(2026, 10, 18)),
                        latest: DateTime(2026, 11, 7),
                      ),
                      loadOrder: () {
                        requests++;
                        return pending.future;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(requests, 0);
        expect(find.text('07.11.2026'), findsOneWidget);
        expect(find.textContaining('Самовывоз'), findsNothing);
        expect(find.textContaining('Вода'), findsNothing);
        final height = tester.getSize(find.byType(ClientLastOrderView)).height;
        expect(height, lessThan(65));
        await tester.tap(find.text('Посмотреть ›'));
        await tester.pump();
        expect(requests, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(edits, 0);
        expect(find.text('Последний заказ — 07.11.2026'), findsOneWidget);
        expect(find.textContaining('05.11.2026'), findsNothing);
        pending.complete(detail(count: 20));
        await tester.pumpAndSettle();
        expect(find.text('Последний заказ — 07.11.2026'), findsOneWidget);
        expect(find.byType(RoutePointTaskHeading), findsOneWidget);
        expect(find.byType(RoutePointTaskTable), findsOneWidget);
        expect(find.byType(TaskItemRow), findsNWidgets(20));
        for (final row in tester.widgetList<TaskItemRow>(
          find.byType(TaskItemRow),
        )) {
          expect(row.enabled, isFalse);
          expect(row.showFullDriverNote, isTrue);
        }
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        expect(
          find.text(
            'Уточнение: Полное примечание строки 19 с длинным текстом для водителя',
          ),
          findsOneWidget,
        );
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -10000),
        );
        await tester.pumpAndSettle();
        expect(find.text('Итого: 247.00 ₽').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Закрыть'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Имя клиента'));
        expect(edits, 1);
      },
    );
  }

  testWidgets('no order has no link even with legacy business summary', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientLastOrderView(
            client: customer(order: order(DateTime(2026, 10, 18))),
            loadOrder: () async {
              requests++;
              return detail();
            },
          ),
        ),
      ),
    );
    expect(find.text('Заказов не было'), findsOneWidget);
    expect(find.text('Посмотреть ›'), findsNothing);
    expect(requests, 0);
  });

  testWidgets('error retries and handles an order cancelled after listing', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientLastOrderView(
            client: customer(latest: DateTime(2026, 11, 7)),
            loadOrder: () async {
              if (++requests == 1) throw Exception('network');
              return null;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Посмотреть ›'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось загрузить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Подходящего заказа больше нет.'), findsOneWidget);
    expect(find.byType(TaskItemRow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed dialog response cannot appear in another client dialog', (
    tester,
  ) async {
    final pending = Completer<ClientLatestOrder?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ClientLastOrderView(
                client: customer(latest: DateTime(2026, 11, 7)),
                loadOrder: () => pending.future,
              ),
              ClientLastOrderView(
                client: customer(latest: DateTime(2026, 11, 6)),
                loadOrder: () async => null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Посмотреть ›').first);
    await tester.pump();
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Посмотреть ›').last);
    await tester.pumpAndSettle();
    pending.complete(detail());
    await tester.pumpAndSettle();
    expect(find.text('Подходящего заказа больше нет.'), findsOneWidget);
    expect(find.byType(TaskItemRow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard status uses orders and renders a customer without orders',
    (tester) async {
      final repo = ClientsFake()
        ..onSearch = (_, _) async => [customer(order: order(DateTime.now()))];
      final provider = ClientsProvider(repo);
      addTearDown(provider.dispose);
      await provider.initializeDashboardClients();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: Scaffold(body: ClientsAttentionListView())),
        ),
      );
      expect(find.text('Заказывает регулярно'), findsOneWidget);
      repo.onSearch = (_, _) async => [customer()];
      await provider.refreshDashboardClients();
      await tester.pumpAndSettle();
      expect(find.text('Заказов не было'), findsNWidgets(2));
      expect(find.text('Последняя доставка'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
