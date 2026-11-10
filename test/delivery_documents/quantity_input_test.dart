import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';

void main() {
  testWidgets(
    'free-price item edits row price and note from the actions menu',
    (
      tester,
    ) async {
      final form = GlobalKey<FormState>();
      var price = 0.0;
      var note = '';
      var item = const DeliveryTaskItem(
        productId: 'service',
        productName: 'Услуга',
        quantity: 2,
        price: 0,
        isFreePrice: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Form(
                key: form,
                child: TaskItemRow(
                  index: 0,
                  allowFreePrice: true,
                  item: item,
                  onDelete: () {},
                  onQuantityChanged: (_) {},
                  onPriceChanged: (value) => setState(() {
                    price = value;
                    item = DeliveryTaskItem(
                      productId: item.productId,
                      productName: item.productName,
                      quantity: item.quantity,
                      price: value,
                      isFreePrice: item.isFreePrice,
                      driverNote: item.driverNote,
                    );
                  }),
                  onDriverNoteChanged: (value) => setState(() {
                    note = value;
                    item = DeliveryTaskItem(
                      productId: item.productId,
                      productName: item.productName,
                      quantity: item.quantity,
                      price: item.price,
                      isFreePrice: item.isFreePrice,
                      driverNote: value,
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final priceField = find.byType(TextFormField).last;
      await tester.enterText(priceField, '12,5');
      await tester.pumpAndSettle();
      expect(price, 12.5);
      expect(find.text('25.00 ₽'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(form.currentState!.validate(), isTrue);

      await tester.enterText(priceField, '1,005');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(priceField).controller!.text,
        '1.005',
      );
      expect(price, 1.005);
      expect(find.text('2.01 ₽'), findsOneWidget);

      await tester.tap(find.byTooltip('Действия с позицией'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Добавить уточнение'), findsOneWidget);
      await tester.tap(find.text('Добавить уточнение'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final noteField = find.byType(TextFormField).last;
      await tester.enterText(noteField, 'Позвонить перед выездом');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(note, 'Позвонить перед выездом');
      expect(find.text('Уточнение: Позвонить перед выездом'), findsOneWidget);
      expect(find.text('Свободная цена'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid quantity has only a border, keeps size and restores valid value',
    (tester) async {
      final form = GlobalKey<FormState>();
      var quantity = 2;
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Form(
                  key: form,
                  child: TaskItemRow(
                    index: 0,
                    enabled: enabled,
                    item: DeliveryTaskItem(
                      productId: 'water',
                      productName: 'Вода',
                      quantity: quantity,
                      price: 350,
                    ),
                    onDelete: () {},
                    onQuantityChanged: (value) =>
                        setState(() => quantity = value),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextFormField);
      final original = tester.getRect(field);
      for (final invalid in ['0', '-1', '', 'abc']) {
        await tester.enterText(field, invalid);
        await tester.pumpAndSettle();
        expect(quantity, 2);
        expect(form.currentState!.validate(), isFalse);
        await tester.pumpAndSettle();
        expect(tester.state<FormFieldState<String>>(field).hasError, isTrue);
        expect(tester.getRect(field), original);
        expect(find.text('Больше 0'), findsNothing);
        expect(find.text('700.00 ₽'), findsOneWidget);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(field).controller!.text, '2');
        expect(form.currentState!.validate(), isTrue);
        await tester.pumpAndSettle();
        expect(tester.state<FormFieldState<String>>(field).hasError, isFalse);
      }
      await tester.enterText(field, '3');
      await tester.pumpAndSettle();
      expect(quantity, 3);
      expect(find.text('1050.00 ₽'), findsOneWidget);
      // Simulate cancelling an editor while its quantity field still has focus.
      update(() {
        quantity = 2;
        enabled = false;
      });
      await tester.pumpAndSettle();
      expect(find.text('700.00 ₽'), findsOneWidget);
      expect(tester.takeException(), isNull);
      update(() => enabled = true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '2');
      await tester.enterText(field, '1');
      await tester.pumpAndSettle();
      final minus = find.widgetWithIcon(IconButton, Icons.remove);
      expect(tester.widget<IconButton>(minus).onPressed, isNull);
      expect(quantity, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
