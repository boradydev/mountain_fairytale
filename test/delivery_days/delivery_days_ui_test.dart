import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_dialog.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_day_list.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_product_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
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

  testWidgets(
    'cards identify driver and pickup creation with clients and total',
    (
      tester,
    ) async {
      final repo = DaysRepository()
        ..days = [day(date)]
        ..documents = [
          DeliveryRouteSheet(
            id: 'delivery',
            date: date,
            createdAt: DateTime(2026, 10, 17, 9, 42),
            driverName: 'Иванов Иван',
            carId: 'car',
            carModelAndNumber: 'Газель А123ВС',
            startMileage: 0,
            points: [
              for (final clientId in ['first', 'first', 'second'])
                RoutePoint(
                  clientId: clientId,
                  clientName: clientId,
                  address: '',
                  phone: '',
                  salesRepresentative: '',
                  items: const [
                    DeliveryTaskItem(
                      productId: 'product',
                      productName: 'Вода',
                      quantity: 1,
                      price: 411.50,
                    ),
                  ],
                ),
            ],
          ),
          PickupSheet(
            id: 'pickup',
            date: date,
            createdAt: DateTime(2026, 10, 17, 10, 15),
            points: [
              for (final clientId in ['first', 'first', 'second'])
                RoutePoint(
                  clientId: clientId,
                  clientName: clientId,
                  address: '',
                  phone: '',
                  salesRepresentative: '',
                  items: const [
                    DeliveryTaskItem(
                      productId: 'product',
                      productName: 'Вода',
                      quantity: 1,
                      price: 411.50,
                    ),
                  ],
                ),
            ],
          ),
        ];
      final provider = DeliveryDaysProvider(repo);
      addTearDown(provider.dispose);
      await provider.fetchDeliveryDays();
      await showDays(tester, provider);
      await tester.tap(find.textContaining('воскресенье'));
      await tester.pumpAndSettle();
      expect(find.text('Доставки'), findsOneWidget);
      expect(find.text('Самовывозы'), findsOneWidget);
      expect(find.text('Иванов Иван'), findsOneWidget);
      expect(find.text('Газель А123ВС'), findsOneWidget);
      expect(find.text('17.10.2026 09:42'), findsOneWidget);
      expect(find.text('17.10.2026 10:15'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data?.replaceAll('\u00a0', ' ') == '1 234,50 ₽',
        ),
        findsNWidgets(2),
      );
      expect(find.text('Самовывоз'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
        expect(find.text('Дата создания неизвестна'), findsNWidgets(count));
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
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      expect(find.text('Дата создания неизвестна — Отменён'), findsOneWidget);
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
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Дата создания неизвестна'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Перенести'));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(find.byType(DayDocumentsDialog), findsOneWidget);
      expect(find.text('На эту дату нет документов'), findsOneWidget);
      expect(
        tester
            .widget<LabeledCheckboxToggle>(find.byType(LabeledCheckboxToggle))
            .value,
        isTrue,
      );
      expect(repo.documentCalls.last, (date, true));
      expect(p.days.single.plannedDate, date.add(const Duration(days: 1)));
      expect(repo.dayCalls.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
