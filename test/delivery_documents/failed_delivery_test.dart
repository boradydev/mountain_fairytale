import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/failed_delivery_dialog.dart';

import 'document_provider_test.dart' show Orders, Catalog, Locks, point;

void main() {
  test('failed purchase keeps goods and saved amount while excluding it from totals; edits preserve state', () {
    final provider = Orders(Catalog(), Locks())..points = [point];
    addTearDown(provider.dispose);
    final total = provider.grandTotal;
    provider.setDeliveryOutcome(
      0,
      delivered: false,
      reason: '  Клиент отсутствует  ',
    );
    expect(provider.grandTotal, 0);
    expect(provider.points.single.totalAmount, total);
    expect(provider.points.single.items, point.items);
    final request = provider.points.single.toRequestJson(creating: false);
    expect(request['isDelivered'], isFalse);
    expect(request['nonDeliveryReason'], 'Клиент отсутствует');
    final saved = RoutePoint.fromJson(provider.points.single.toJson());
    expect(saved.copyWith(items: point.items).isDelivered, isFalse);
    expect(saved.nonDeliveryReason, 'Клиент отсутствует');
    provider.setDeliveryOutcome(0, delivered: true);
    expect(provider.grandTotal, total);
    expect(provider.points.single.nonDeliveryReason, '');
    provider.setDeliveryOutcome(0, delivered: false, reason: '  ');
    expect(provider.points.single.isDelivered, isTrue);
    provider.isEditing = false;
    provider.documentId = 'saved';
    provider.setDeliveryOutcome(
      0,
      delivered: false,
      reason: 'No change in view',
    );
    expect(provider.points.single.isDelivered, isTrue);
  });

  testWidgets('reason is required and cancelling applies no outcome', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const FailedDeliveryDialog(),
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите причину'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.byType(TextFormField), '  Нет доступа  ');
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(result, 'Нет доступа');
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
