import 'dart:typed_data';

import 'package:mountain_fairytale/features/clients/data/location_repository.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/clients/ui/client_location_dialog.dart';

import 'clients_ui_test.dart' show FakeLocations, testAddress;

class TrackingMap extends FakeLocations {
  final levels = <int>[];
  @override
  Future<Uint8List> tile(int z, int x, int y) {
    levels.add(z);
    return super.tile(z, x, y);
  }
}

void main() {
  testWidgets(
    'wheel, pinch and buttons zoom without moving the delivery marker',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TrackingMap();
      DeliveryAddress? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showClientLocationDialog(
                    context,
                    repository: repo,
                    address: testAddress.formatted,
                    candidates: [],
                    existing: testAddress,
                  );
                },
                child: const Text('Карта'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Карта'));
      await tester.pumpAndSettle();
      final map = find.byKey(const ValueKey('client-location-map'));
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      final focal = tester.getCenter(map) + const Offset(-150, 0);
      expect(repo.levels.last, 17);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: focal, scrollDelta: const Offset(0, -120)),
      );
      await tester.pumpAndSettle();
      expect(repo.levels.last, 18);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: focal, scrollDelta: const Offset(0, 120)),
      );
      await tester.pumpAndSettle();
      expect(repo.levels.last, 17);
      final first = await tester.createGesture(pointer: 1);
      final second = await tester.createGesture(pointer: 2);
      await first.down(focal - const Offset(25, 0));
      await second.down(focal + const Offset(25, 0));
      await tester.pump();
      await first.moveTo(focal - const Offset(80, 0));
      await second.moveTo(focal + const Offset(80, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(repo.levels.last, greaterThan(17));
      await tester.ensureVisible(find.byTooltip('Отдалить'));
      await tester.tap(find.byTooltip('Отдалить'));
      await tester.pumpAndSettle();
      expect(repo.levels.last, lessThan(19));
      await tester.tap(find.text('Подтвердить местоположение'));
      await tester.pumpAndSettle();
      expect(selected?.latitude, testAddress.latitude);
      expect(selected?.longitude, testAddress.longitude);
      expect(tester.takeException(), isNull);
    },
  );
}
