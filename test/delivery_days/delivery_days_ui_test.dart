import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_dialog.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_day_list.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_product_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';

import 'delivery_days_provider_test.dart' show DaysRepository, day;

void main() {
  testWidgets(
    'narrow dialog keeps creation actions and close visible; card refresh errors can retry',
    (tester) async {
      tester.view.physicalSize = const Size(380, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DaysRepository()..failDays = true;
      final p = DeliveryDaysProvider(repo);
      addTearDown(p.dispose);
      await p.refreshDeliveryDays();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Открыть'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DayDocumentsDialog(
                    date: DateTime(2026, 10, 18),
                    daysProvider: p,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить доставку').hitTestable(), findsOneWidget);
      expect(find.text('Добавить самовывоз').hitTestable(), findsOneWidget);
      expect(find.text('Закрыть').hitTestable(), findsOneWidget);
      expect(find.text('Обновить карточки'), findsOneWidget);
      expect(tester.takeException(), isNull);
      repo.failDays = false;
      await tester.ensureVisible(find.text('Обновить карточки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить карточки'));
      await tester.pumpAndSettle();
      expect(find.text('Обновить карточки'), findsNothing);
      expect(find.byType(DayDocumentsDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  final date = DateTime(2026, 10, 18);
  Future<void> showDays(WidgetTester tester, DeliveryDaysProvider p) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: DeliveryDaysListView(scrollController: scroll),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final count in [0, 1, 3]) {
    testWidgets('card always opens day dialog for $count documents', (
      tester,
    ) async {
      final repo = DaysRepository()
        ..days = [day(date)]
        ..documents = List.generate(
          count,
          (i) => PickupSheet(id: '$i', date: date, points: []),
        );
      final p = DeliveryDaysProvider(repo);
      addTearDown(p.dispose);
      await p.fetchDeliveryDays();
      await showDays(tester, p);
      expect(find.textContaining('воскресенье'), findsOneWidget);
      expect(find.text('Выходной'), findsOneWidget);
      expect(find.text('Документы доставки и самовывоза'), findsNothing);
      await tester.tap(find.textContaining('воскресенье'));
      await tester.pumpAndSettle();
      expect(find.byType(DayDocumentsDialog), findsOneWidget);
      expect(find.text('Добавить самовывоз'), findsOneWidget);
      expect(repo.documentCalls, [(date, false)]);
      if (count == 0) {
        expect(
          find.text('На эту дату нет активных документов'),
          findsOneWidget,
        );
      } else {
        expect(find.text('Самовывоз'), findsNWidgets(count));
      }
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(repo.dayCalls.length, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'historical names render without product catalog and have a full tooltip',
    (tester) async {
      const name =
          'Вода Горная / Вода Родниковая / Очень длинное историческое название';
      final repo = DaysRepository()
        ..days = [
          DeliveryDay(
            plannedDate: date,
            deliveryPointsCount: 8,
            pickupPointsCount: 2,
            products: [
              const DeliveryDayProduct(
                productId: 'uuid',
                productName: name,
                quantity: 14,
              ),
            ],
            totalAmount: 3510.5,
          ),
        ];
      final p = DeliveryDaysProvider(repo);
      addTearDown(p.dispose);
      await p.fetchDeliveryDays();
      await showDays(tester, p);
      expect(find.text('Точки доставки'), findsOneWidget);
      expect(find.text('Точки самовывоза'), findsOneWidget);
      expect(find.text('Возвраты'), findsNothing);
      expect(find.text('3510.50 ₽'), findsOneWidget);
      expect(find.byTooltip(name), findsOneWidget);
      final label = tester.widget<Text>(find.text(name));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty or failed calendar keeps add action and retry', (
    tester,
  ) async {
    final repo = DaysRepository()..failDays = true;
    final p = DeliveryDaysProvider(repo);
    addTearDown(p.dispose);
    await p.fetchDeliveryDays();
    await showDays(tester, p);
    expect(find.text('Добавить доставку'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    repo.failDays = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Документов пока нет.'), findsOneWidget);
    expect(find.text('Добавить доставку'), findsOneWidget);
    expect(find.byType(DeliveryDayItem), findsNothing);
  });

  testWidgets(
    'day filter retries failed reads and stays accessible with empty documents',
    (tester) async {
      final repo = DaysRepository()..failDocuments = true;
      final p = DeliveryDaysProvider(repo);
      addTearDown(p.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DayDocumentsDialog(date: date, daysProvider: p),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.text('Добавить доставку'), findsOneWidget);
      expect(find.text('Добавить самовывоз'), findsOneWidget);
      repo.failDocuments = false;
      repo.documents = [
        PickupSheet(id: 'cancelled', date: date, isActive: false, points: []),
      ];
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('На эту дату нет активных документов'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Самовывоз — Отменён'), findsOneWidget);
      expect(repo.documentCalls.last, (date, true));
    },
  );

  testWidgets(
    'moving a document refreshes calendar and same day dialog, preserving filter',
    (tester) async {
      final repo = DaysRepository()
        ..days = [day(date)]
        ..documents = [PickupSheet(id: 'document', date: date, points: [])];
      final p = DeliveryDaysProvider(repo);
      addTearDown(p.dispose);
      await p.fetchDeliveryDays();
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('День'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DayDocumentsDialog(
                    date: date,
                    daysProvider: p,
                    openDocument:
                        (context, type, initialDate, document, changed) async {
                          opens++;
                          expect(initialDate, date);
                          expect(document!.id, 'document');
                          return Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                body: TextButton(
                                  child: const Text('Перенести'),
                                  onPressed: () {
                                    final newDate = date.add(
                                      const Duration(days: 1),
                                    );
                                    repo.documents = [
                                      PickupSheet(
                                        id: 'document',
                                        date: newDate,
                                        points: [],
                                      ),
                                    ];
                                    repo.days = [day(newDate)];
                                    changed();
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('День'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Самовывоз'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Перенести'));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(find.byType(DayDocumentsDialog), findsOneWidget);
      expect(find.text('На эту дату нет документов'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(repo.documentCalls.last, (date, true));
      expect(p.days.single.plannedDate, date.add(const Duration(days: 1)));
      expect(repo.dayCalls.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
