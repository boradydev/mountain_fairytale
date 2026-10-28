import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';

void main() {
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
