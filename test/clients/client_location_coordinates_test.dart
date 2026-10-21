import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/features/clients/ui/client_location_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

import 'clients_ui_test.dart' show FakeLocations, field, testAddress;

void main() {
  late FakeLocations geo;
  DeliveryAddress? selected;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    geo = FakeLocations()..fail = true;
    selected = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => selected = await showClientLocationDialog(
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
    await tester.ensureVisible(find.text('Ввести координаты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ввести координаты'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('Координаты из карты'));
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Показать координаты на карте'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать координаты на карте'));
    await tester.pumpAndSettle();
  }

  String value(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(field(label)).controller!.text;

  testWidgets(
    'pasted latitude-longitude pair fills fields and confirms without geocoding',
    (tester) async {
      await open(tester);
      await tester.enterText(
        field('Координаты из карты'),
        ' 43.948310, 42.663921 ',
      );
      await tester.pumpAndSettle();
      expect(double.parse(value(tester, 'Широта')), 43.948310);
      expect(double.parse(value(tester, 'Долгота')), 42.663921);
      expect(
        tester
            .widget<AppPrimaryButton>(
              find.widgetWithText(
                AppPrimaryButton,
                'Подтвердить местоположение',
              ),
            )
            .onPressed,
        isNull,
      );
      await apply(tester);
      await tester.tap(find.text('Подтвердить местоположение'));
      await tester.pumpAndSettle();
      expect(selected!.latitude, 43.948310);
      expect(selected!.longitude, 42.663921);
      expect(selected!.source, 'manual');
      expect(geo.searches, 0);
    },
  );

  testWidgets(
    'invalid pairs never confirm old coordinates and correction clears the error',
    (tester) async {
      await open(tester);
      for (final invalid in [
        'abc',
        '43.948310',
        '43.948310,42.663921,17',
        'NaN,42.663921',
        '43.948310,Infinity',
        '42.663921,43.948310',
        '55.75,37.61',
        '43,948310,42,663921',
      ]) {
        await tester.ensureVisible(field('Координаты из карты'));
        await tester.enterText(field('Координаты из карты'), invalid);
        await tester.pumpAndSettle();
        await apply(tester);
        expect(
          tester
              .widget<AppPrimaryButton>(
                find.widgetWithText(
                  AppPrimaryButton,
                  'Подтвердить местоположение',
                ),
              )
              .onPressed,
          isNull,
        );
        final input = find.descendant(
          of: field('Координаты из карты'),
          matching: find.byType(TextField),
        );
        expect(
          tester.widget<TextField>(input).decoration!.errorText,
          isNotNull,
        );
      }
      await tester.ensureVisible(field('Координаты из карты'));
      await tester.enterText(
        field('Координаты из карты'),
        '43.948310,42.663921',
      );
      await tester.pumpAndSettle();
      await apply(tester);
      expect(
        tester
            .widget<AppPrimaryButton>(
              find.widgetWithText(
                AppPrimaryButton,
                'Подтвердить местоположение',
              ),
            )
            .onPressed,
        isNotNull,
      );
      final input = find.descendant(
        of: field('Координаты из карты'),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(input).decoration!.errorText, isNull);
    },
  );

  testWidgets('individual field edit replaces pasted pair and remains usable', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('Координаты из карты'), '43.948310,42.663921');
    await tester.ensureVisible(field('Широта'));
    await tester.enterText(field('Широта'), '44,012345');
    await tester.pumpAndSettle();
    expect(value(tester, 'Координаты из карты'), isEmpty);
    await apply(tester);
    await tester.tap(find.text('Подтвердить местоположение'));
    await tester.pumpAndSettle();
    expect(selected!.latitude, 44.012345);
    expect(selected!.longitude, 42.663921);
    expect(selected!.source, 'manual');
  });
}
