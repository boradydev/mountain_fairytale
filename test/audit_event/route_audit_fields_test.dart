import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audit_event_style_test.dart' as fixtures;

void main() {
  testWidgets(
    'document audit discloses memo, delivery outcome and independent row notes',
    (tester) async {
      final before = {
        'pointId': 'point',
        'clientId': 'customer',
        'position': 0,
        'memo': 'Старая памятка',
        'isDelivered': true,
        'nonDeliveryReason': '',
        'items': [
          {
            'itemId': 'row1',
            'productId': 'service',
            'productName': 'Услуга',
            'quantity': 1,
            'price': 1.005,
            'isFreePrice': true,
            'driverNote': 'Первое уточнение',
          },
          {
            'itemId': 'row2',
            'productId': 'service',
            'productName': 'Услуга',
            'quantity': 1,
            'price': 5,
            'isFreePrice': true,
            'driverNote': 'Второе уточнение',
          },
        ],
      };
      final items = before['items'] as List<Map<String, Object>>;
      final after = {
        ...before,
        'memo': 'Новая памятка',
        'isDelivered': false,
        'nonDeliveryReason': 'Закрыто',
        'items': [
          {...items[0], 'driverNote': 'Изменено уточнение'},
          items[1],
        ],
      };
      await fixtures.pumpRows(tester, [
        fixtures.sample(
          'route-fields',
          type: 'delivery_document',
          action: 'updated',
          changes: {
            'points': {
              'oldValue': [before],
              'newValue': [after],
            },
          },
        ),
      ]);
      await tester.tap(find.byKey(const ValueKey('audit-header-route-fields')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Клиенты · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('customer · товаров: 2'));
      await tester.pumpAndSettle();
      expect(find.text('Памятка водителю'), findsOneWidget);
      expect(find.textContaining('Новая памятка'), findsOneWidget);
      expect(find.text('Доставка состоялась'), findsOneWidget);
      expect(find.textContaining('Закрыто'), findsOneWidget);
      expect(find.textContaining('Изменено уточнение'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
