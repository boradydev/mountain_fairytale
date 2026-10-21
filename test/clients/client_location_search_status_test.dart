import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/features/clients/ui/client_location_dialog.dart';

import 'clients_ui_test.dart' show FakeLocations, testAddress;

class PendingLocations extends FakeLocations {
  var pending = Completer<List<LocationCandidate>>();
  int calls = 0;
  @override
  Future<List<LocationCandidate>> search(Map<String, String> address) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'map stays in place through idle, loading, long result and error',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final geo = PendingLocations();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showClientLocationDialog(
                  context,
                  repository: geo,
                  address: testAddress.formatted,
                  existing: testAddress,
                ),
                child: const Text('Карта'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Карта'));
      await tester.pumpAndSettle();
      final map = find.byKey(const ValueKey('client-location-map'));
      final status = find.byKey(const ValueKey('location-search-status'));
      final originalMap = tester.getRect(map);
      final originalStatus = tester.getRect(status);
      void checkPosition() {
        expect(tester.getRect(map), originalMap);
        expect(tester.getRect(status), originalStatus);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.text('Найти адрес'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(
          of: status,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('Ищем адрес…'), findsOneWidget);
      checkPosition();
      await tester.tap(find.text('Найти адрес'));
      expect(geo.calls, 1);
      geo.pending.complete([
        LocationCandidate({
          'formatted': List.filled(
            15,
            'Очень длинный адрес с названием улицы и района',
          ).join(', '),
          'latitude': testAddress.latitude,
          'longitude': testAddress.longitude,
          'confidence': 1.0,
          'exactHouse': true,
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Найдено:'), findsOneWidget);
      checkPosition();

      geo.pending = Completer();
      await tester.tap(find.text('Найти адрес'));
      await tester.pump(const Duration(milliseconds: 200));
      checkPosition();
      geo.pending.completeError(
        const ApiException(
          statusCode: 503,
          message: 'Geolocation service is unavailable.',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Сервис поиска адресов временно недоступен.'),
        findsOneWidget,
      );
      expect(find.text('Geolocation service is unavailable.'), findsNothing);
      checkPosition();

      geo.pending = Completer();
      await tester.tap(find.text('Найти адрес'));
      await tester.pump();
      final fallback = List.filled(
        10,
        'Unexpected provider response.',
      ).join('\n');
      geo.pending.completeError(
        ApiException(statusCode: 502, message: fallback),
      );
      await tester.pumpAndSettle();
      expect(find.text(fallback), findsOneWidget);
      checkPosition();

      geo.pending = Completer();
      await tester.tap(find.text('Найти адрес'));
      await tester.pump();
      geo.pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Адрес не найден.'), findsOneWidget);
      checkPosition();
    },
  );
}
