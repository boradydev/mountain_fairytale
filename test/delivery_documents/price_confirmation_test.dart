import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_points_list.dart';

import 'document_provider_test.dart'
    show Orders, Catalog, Locks, Clients, point;

void main() {
  testWidgets(
    'price confirmation controls only selected row; invalid quantity blocks form',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = Catalog()
        ..price = 25
        ..name = 'Переименованный товар';
      final provider = Orders(catalog, Locks())..points = [point];
      final clients = ClientsProvider(Clients());
      final formKey = GlobalKey<FormState>();
      addTearDown(provider.dispose);
      addTearDown(clients.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: clients,
          child: MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: provider,
                builder: (context, _) => Form(
                  key: formKey,
                  child: RoutePointsList(provider: provider),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Клиент'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Действия с позицией'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить цену из каталога'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Сохранённая цена: 1.005 ₽. Цена каталога: 25.0 ₽.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(provider.points.single.items.single.price, 1.005);
      await tester.tap(find.byTooltip('Действия с позицией'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить цену из каталога'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить цену'));
      await tester.pumpAndSettle();
      expect(provider.points.single.items.single.price, 25);
      expect(provider.points.single.items.single.quantity, 2);
      expect(provider.points.single.items.single.productName, 'Товар');
      expect(find.text('Товар'), findsWidgets);
      expect(find.text('Переименованный товар'), findsNothing);
      catalog.active = false;
      catalog.price = 50;
      await tester.tap(find.byTooltip('Действия с позицией'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить цену из каталога'));
      await tester.pumpAndSettle();
      expect(find.text('Обновить цену строки?'), findsNothing);
      expect(provider.points.single.items.single.price, 25);
      final quantityField = find.byType(TextFormField).last;
      await tester.enterText(quantityField, '4');
      await tester.pump();
      expect(provider.points.single.items.single.quantity, 4);
      await tester.enterText(quantityField, '0');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Больше 0'), findsOneWidget);
      expect(provider.points.single.items.single.quantity, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
