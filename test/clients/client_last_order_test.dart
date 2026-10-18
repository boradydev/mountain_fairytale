import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/client_last_order.dart';
import 'package:mountain_fairytale/features/clients/ui/client_list.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:provider/provider.dart';

import 'clients_ui_test.dart' show ClientsFake;

Client customer({ClientLastOrder? order, DateTime? cooldown}) => Client(
  id: 'customer',
  name: 'Клиент',
  phone: '+79123456789',
  address: 'Адрес',
  sleepingThresholdDays: 10,
  createdAt: DateTime(2026),
  isActive: true,
  lastOrder: order,
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

  test('recent pickup leaves follow-up list; older order and cooldown are respected', () async {
    final now = DateTime.now();
    final repo = ClientsFake()
      ..onSearch = (_, _) async => [customer(order: order(now))];
    final provider = ClientsProvider(repo);
    addTearDown(provider.dispose);
    await provider.fetchClients();
    provider.setListMode(ClientListMode.followUp);
    expect(provider.sortedClients, isEmpty);
    repo.onSearch = (_, _) async => [
      customer(order: order(now.subtract(const Duration(days: 11)))),
    ];
    await provider.fetchClients(force: true);
    expect(provider.sortedClients, hasLength(1));
    repo.onSearch = (_, _) async => [
      customer(
        order: order(now.subtract(const Duration(days: 11))),
        cooldown: now.add(const Duration(days: 1)),
      ),
    ];
    await provider.fetchClients(force: true);
    expect(provider.sortedClients, isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'preview and full composition have separate card actions in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var edits = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.createTheme(brightness),
            home: Scaffold(
              body: AppBaseCard(
                onTap: () => edits++,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Имя клиента'),
                    ClientLastOrderView(
                      client: customer(order: order(DateTime(2026, 10, 18))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('Самовывоз'), findsOneWidget);
        expect(
          find.text('Вода 19 л × 2 · Помпа × 1 · ещё 2 позиции'),
          findsOneWidget,
        );
        expect(find.text('Стаканы × 10'), findsNothing);
        await tester.tap(find.text('Последний заказ'));
        await tester.pumpAndSettle();
        expect(edits, 0);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Стаканы × 10'), findsOneWidget);
        expect(find.text('Чехол × 1'), findsOneWidget);
        await tester.tap(find.text('Закрыть'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Имя клиента'));
        expect(edits, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'dashboard status uses orders and renders a customer without orders',
    (tester) async {
      final repo = ClientsFake()
        ..onSearch = (_, _) async => [customer(order: order(DateTime.now()))];
      final provider = ClientsProvider(repo);
      addTearDown(provider.dispose);
      await provider.fetchClients();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: Scaffold(body: ClientsAttentionListView())),
        ),
      );
      expect(find.text('Заказывает регулярно'), findsOneWidget);
      repo.onSearch = (_, _) async => [customer()];
      await provider.fetchClients(force: true);
      await tester.pumpAndSettle();
      expect(find.text('Заказов не было'), findsNWidgets(2));
      expect(find.text('Последняя доставка'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
