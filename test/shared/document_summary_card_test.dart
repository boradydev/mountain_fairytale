import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/shared/widgets/dialog_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/document_summary_card.dart';

void main() {
  for (final count in [null, '3']) {
    for (final amount in [null, '100 ₽']) {
      for (final extra in [false, true]) {
        testWidgets(
          'optional fields count=$count amount=$amount extra=$extra',
          (
            tester,
          ) async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: DocumentSummaryCard(
                    isPickup: false,
                    date: '05.11.2026',
                    count: count,
                    amount: amount,
                    createdAt: extra ? '04.11.2026 12:30' : null,
                    title: extra ? 'Доставка' : null,
                    onOpen: () {},
                  ),
                ),
              ),
            );
            expect(
              find.text('Клиентов:'),
              count == null ? findsNothing : findsOneWidget,
            );
            expect(
              find.text('Сумма:'),
              amount == null ? findsNothing : findsOneWidget,
            );
            expect(find.text('Создан:'), extra ? findsOneWidget : findsNothing);
            expect(
              find.text('Доставка'),
              extra ? findsOneWidget : findsNothing,
            );
            expect(find.text('Отменён'), findsNothing);
            expect(
              tester.widget<Table>(find.byType(Table)).children.length,
              3 +
                  (count == null ? 0 : 1) +
                  (amount == null ? 0 : 1) +
                  (extra ? 1 : 0),
            );
            if (extra) {
              expect(
                tester.getTopLeft(find.text('Создан:')).dy,
                greaterThan(tester.getTopLeft(find.text('Дата:')).dy),
              );
              expect(
                tester.getTopLeft(find.text('Создан:')).dy,
                lessThan(tester.getTopLeft(find.text('Водитель:')).dy),
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  const driver = 'Иванов Иван Иванович очень длинное имя водителя маршрута';
  const car = 'Очень длинная модель автомобиля с номером А123ВС777';
  for (final brightness in Brightness.values) {
    for (final width in [240.0, 320.0, 560.0]) {
      for (final scale in [1.0, 1.8]) {
        for (final isPickup in [false, true]) {
          testWidgets(
            'summary $brightness width=$width scale=$scale pickup=$isPickup',
            (tester) async {
              var opened = 0;
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: Center(
                        child: SizedBox(
                          width: width,
                          child: MediaQuery(
                            data: MediaQueryData(
                              textScaler: TextScaler.linear(scale),
                            ),
                            child: DocumentSummaryCard(
                              isPickup: isPickup,
                              date: '05.11.2026',
                              count: '3',
                              amount: '1 234,50 ₽',
                              driver: driver,
                              car: car,
                              isActive: false,
                              onOpen: () => opened++,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final labels = [
                'Дата:',
                isPickup ? 'Покупок:' : 'Клиентов:',
                'Сумма:',
                if (!isPickup) ...['Водитель:', 'Автомобиль:'],
              ];
              final table = find.byType(Table);
              expect(
                tester.widget<Table>(table).children.length,
                isPickup ? 3 : 5,
              );
              var previousTop = -1.0;
              for (final label in labels) {
                final top = tester.getTopLeft(find.text(label)).dy;
                expect(top, greaterThan(previousTop));
                previousTop = top;
              }
              expect(find.text('Отменён'), findsOneWidget);
              expect(find.textContaining('Создан'), findsNothing);
              expect(find.textContaining('Плановая'), findsNothing);
              for (final value in [
                '05.11.2026',
                '3',
                '1 234,50 ₽',
                if (!isPickup) ...[driver, car],
              ]) {
                final text = tester.widget<Text>(find.text(value));
                expect(text.maxLines, 1);
                expect(text.softWrap, false);
                expect(text.overflow, TextOverflow.ellipsis);
                expect(find.byTooltip(value), findsOneWidget);
              }
              if (!isPickup && width == 320 && scale == 1) {
                final paragraph = tester.renderObject<RenderParagraph>(
                  find.text(driver),
                );
                expect(paragraph.didExceedMaxLines, true);
                final mouse = await tester.createGesture(
                  kind: PointerDeviceKind.mouse,
                );
                await mouse.addPointer(location: Offset.zero);
                await mouse.moveTo(tester.getCenter(find.text(driver)));
                await tester.pump(const Duration(seconds: 1));
                expect(find.text(driver), findsNWidgets(2));
                await mouse.removePointer();
                await tester.pumpAndSettle();
              }
              final surface = find.descendant(
                of: find.byType(AppDialogCard),
                matching: find.byType(Material),
              );
              final center = tester.getCenter(surface).dy;
              expect(
                tester
                    .getCenter(
                      find.byIcon(
                        isPickup
                            ? Icons.store_outlined
                            : Icons.local_shipping_outlined,
                      ),
                    )
                    .dy,
                closeTo(center, .01),
              );
              expect(
                tester.getCenter(find.byIcon(Icons.chevron_right)).dy,
                closeTo(center, .01),
              );
              final colors = Theme.of(tester.element(surface)).colorScheme;
              expect(
                tester.widget<Material>(surface).color,
                colors.surfaceContainerLow,
              );
              // The blank padded surface opens the document too.
              await tester.tapAt(
                tester.getTopLeft(surface) + const Offset(6, 6),
              );
              expect(opened, 1);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
