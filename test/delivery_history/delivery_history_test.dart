import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_history/delivery_history_abcs.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/delivery_history_provider.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/delivery_history_screen.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/client_delivery_card.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/history_document_card.dart';
import 'package:mountain_fairytale/shared/widgets/app_date_range_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/dialog_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/document_summary_card.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_point_card_content.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/task_item_row.dart';

Map<String, dynamic> _json(String id) => {
  'pointId': id,
  'clientId': 'client',
  'clientName': 'Исторический клиент',
  'address': 'Сохранённый адрес',
  'clientAddress': 'Сохранённый адрес',
  'deliveryDetails': '',
  'phone': '123',
  'memo': 'Задание',
  'isDelivered': false,
  'nonDeliveryReason': 'Закрыто',
  'paymentMethodName': 'Наличные',
  'salesRepresentativeName': 'Исторический представитель',
  'deliveryDocumentId': 'route-$id',
  'plannedDate': '2026-11-03',
  'createdAt': '2026-11-02T12:30:00',
  'driverName': 'Водитель',
  'carModelAndNumber': 'Машина',
  'documentTotalAmount': '900.50',
  'clientsCount': 3,
  'totalAmount': '200.00',
  'items': [
    {
      'productId': 'product',
      'itemId': 'item',
      'productName': 'Исторический товар',
      'quantity': 2,
      'price': '100.00',
      'amount': '200.00',
      'isFreePrice': true,
      'driverNote': 'Уточнение',
    },
  ],
};
ClientDeliveryHistoryPage _page(List<String> ids, int total) =>
    ClientDeliveryHistoryPage.fromJson({
      'total': total,
      'data': {'deliveries': ids.map(_json).toList()},
    });

class _Request {
  final int offset;
  final int limit;
  final String search;
  final Completer<ClientDeliveryHistoryPage> result = Completer();
  _Request(this.offset, this.limit, this.search);
}

class _Repository implements DeliveryHistoryRepository {
  final requests = <_Request>[];
  bool automatic = false;
  int rows = 0;
  final documentOffsets = <int>[];
  final documentLimits = <int>[];
  String? documentType;
  String? documentSearch;
  bool? cancelled;
  @override
  Future<ClientDeliveryHistoryPage> getClientHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String search,
    required int offset,
    required int limit,
  }) {
    final request = _Request(offset, limit, search);
    requests.add(request);
    if (automatic) {
      request.result.complete(
        _page(
          List.generate(
            (rows - offset).clamp(0, limit),
            (i) => '${offset + i}',
          ),
          rows,
        ),
      );
    }
    return request.result.future;
  }

  @override
  Future<DeliveryHistoryPage> getHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String search,
    required bool includeCancelled,
    required int offset,
    required int limit,
    String documentType = 'all',
  }) async {
    this.documentType = documentType;
    documentSearch = search;
    cancelled = includeCancelled;
    documentOffsets.add(offset);
    documentLimits.add(limit);
    return DeliveryHistoryPage(
      documents: List.generate(
        (rows - offset).clamp(0, limit),
        (i) => ClientDelivery.fromJson(_json('${offset + i}')).document,
      ),
      total: rows,
    );
  }
}

final _captureKey = GlobalKey();
Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'NotoSans', brightness: brightness),
        home: Scaffold(body: child),
      ),
    );
void main() {
  setUpAll(() async {
    final loader = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await loader.load();
  });
  test(
    '50 rows, stale answers, deduplication, retry and independent filters',
    () async {
      final repo = _Repository();
      final provider = DeliveryHistoryProvider(
        repo,
        now: () => DateTime(2026, 11, 3),
      );
      addTearDown(provider.dispose);
      expect(provider.dateRange.start, DateTime(2026, 10, 5));
      final old = provider.refresh();
      final current = provider.setSearch('Текущий клиент');
      expect(repo.requests.last.limit, 50);
      repo.requests[1].result.complete(_page(['new'], 3));
      await current;
      repo.requests[0].result.complete(_page(['stale'], 100));
      await old;
      expect(provider.deliveries.single.pointId, 'new');
      final next = provider.loadMore();
      await provider.loadMore();
      expect(repo.requests.length, 3);
      expect(repo.requests.last.offset, 1);
      repo.requests.last.result.completeError(Exception('offline'));
      await next;
      expect(provider.error, isNotNull);
      expect(provider.deliveries.length, 1);
      final retry = provider.loadMore();
      expect(repo.requests.last.offset, 1);
      repo.requests.last.result.complete(_page(['new', 'second'], 3));
      await retry;
      expect(provider.deliveries.length, 2);
      expect(provider.hasMore, isFalse);
      await provider.setClientsMode(false);
      await provider.setIncludeCancelled(true);
      await provider.setDocumentType('pickup_sheet');
      expect(repo.documentType, 'pickup_sheet');
      expect(repo.documentSearch, '');
      expect(repo.cancelled, true);
      repo.automatic = true;
      await provider.setClientsMode(true);
      expect(provider.search, 'Текущий клиент');
      expect(provider.documentType, 'pickup_sheet');
      expect(provider.includeCancelled, true);
      expect(provider.dateRange.start, DateTime(2026, 10, 5));
    },
  );
  test('calendar year includes leap day and rejects longer ranges', () async {
    final repo = _Repository()..automatic = true;
    final provider = DeliveryHistoryProvider(repo);
    addTearDown(provider.dispose);
    await provider.setDateRange(
      DateTimeRange(start: DateTime(2024, 2, 29), end: DateTime(2025, 2, 28)),
    );
    await expectLater(
      provider.setDateRange(
        DateTimeRange(start: DateTime(2024, 2, 29), end: DateTime(2025, 3, 1)),
      ),
      throwsArgumentError,
    );
    expect(repo.requests.length, 1);
  });
  for (final width in [390.0, 1100.0]) {
    testWidgets(
      'client expands independently and route stays compact at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        await tester.pumpWidget(
          _app(
            ListView(
              children: [
                ClientDeliveryCard(
                  delivery: ClientDelivery.fromJson(_json('one')),
                  onOpen: () => opened++,
                ),
              ],
            ),
          ),
        );
        final routeText = find.textContaining('900,50');
        final routeCard = find.descendant(
          of: find.byType(AppDialogCard),
          matching: find.byType(Material),
        );
        final routeSize = tester.getSize(routeCard);
        final before = tester.getTopLeft(routeText);
        expect(find.text('Дата:'), findsOneWidget);
        expect(find.text('Водитель:'), findsOneWidget);
        expect(find.text('Автомобиль:'), findsOneWidget);
        expect(find.text('Сумма:'), findsOneWidget);
        expect(find.textContaining('Создан:'), findsNothing);
        expect(find.byType(DocumentSummaryCard), findsOneWidget);
        expect(find.text('Клиентов:'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        if (width > 760) {
          final surface = find.byType(RoutePointCardSurface);
          expect(tester.getSize(routeCard).width, inInclusiveRange(280, 370));
          expect(
            tester.getSize(routeCard).width,
            lessThanOrEqualTo(tester.getSize(surface).width),
          );
          expect(
            tester.getTopLeft(routeCard).dy,
            tester.getTopLeft(surface).dy,
          );
          await tester.tap(find.byIcon(Icons.link), warnIfMissed: false);
          await tester.pumpAndSettle();
          expect(opened, 0);
          expect(find.byType(TaskItemRow), findsNothing);
        } else {
          expect(find.byIcon(Icons.link), findsNothing);
          expect(
            tester.getBottomLeft(routeCard).dy,
            lessThan(tester.getTopLeft(find.byType(RoutePointCardSurface)).dy),
          );
        }
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(opened, 0);
        expect(tester.getTopLeft(routeText), before);
        expect(tester.getSize(routeCard), routeSize);
        final qaDir = Platform.environment['DELIVERY_HISTORY_QA_DIR'];
        if (qaDir != null) {
          await tester.runAsync(() async {
            final boundary =
                _captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$qaDir/client-history-$width.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(find.text('Исторический товар'), findsOneWidget);
        expect(
          find.text('Исторический представитель'),
          findsOneWidget,
        );
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(routeText);
        expect(opened, 1);
      },
    );
  }
  for (final width in [320.0, 800.0]) {
    testWidgets('client summary fits enlarged text at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final long = List.filled(10, 'Очень длинное значение').join(' ');
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: ListView(
              children: [
                ClientDeliveryCard(
                  delivery: ClientDelivery.fromJson({
                    ..._json('scaled'),
                    'driverName': long,
                    'carModelAndNumber': long,
                  }),
                  onOpen: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(DocumentSummaryCard), findsOneWidget);
      expect(find.byTooltip(long), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 680.0, 1100.0, 1500.0]) {
    testWidgets(
      'history snapshots, long text and independent expansion at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final longText = List.filled(
          12,
          'Длинный исторический текст',
        ).join(' ');
        final json = _json('first');
        final item = Map<String, dynamic>.from(
          (json['items'] as List).first as Map,
        );
        final data = {
          ...json,
          'clientName': longText,
          'driverName': longText,
          'carModelAndNumber': longText,
          'address': longText,
          'memo': longText,
          'nonDeliveryReason': longText,
          'salesRepresentativeName': longText,
          'items': [
            {...item, 'driverNote': longText},
            {
              ...item,
              'itemId': 'second-item',
              'price': '125.50',
              'driverNote': 'Вторая строка',
            },
          ],
        };
        await tester.pumpWidget(
          _app(
            ListView(
              children: [
                ClientDeliveryCard(
                  delivery: ClientDelivery.fromJson(data),
                  onOpen: () {},
                ),
                ClientDeliveryCard(
                  delivery: ClientDelivery.fromJson(_json('second')),
                  onOpen: () {},
                ),
              ],
            ),
          ),
        );
        final surfaces = find.byType(RoutePointCardSurface);
        expect(
          tester.widget<RoutePointCardSurface>(surfaces.first).isDelivered,
          isFalse,
        );
        expect(find.byType(TaskItemRow), findsNothing);
        final firstTile = find.byType(ExpansionTile).first;
        await tester.tap(
          find.descendant(of: firstTile, matching: find.byType(ListTile)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TaskItemRow), findsNWidgets(2));
        expect(find.text('Итого: 451.00 ₽'), findsOneWidget);
        expect(find.text('Форма оплаты'), findsOneWidget);
        expect(find.text('Торговый представитель'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        final note = tester.widget<Text>(find.text('Уточнение: $longText'));
        expect(note.maxLines, isNull);
        expect(
          tester.widget<Text>(find.text('Итого: 451.00 ₽')).style!.decoration,
          TextDecoration.lineThrough,
        );
        final row = tester.widget<TaskItemRow>(find.byType(TaskItemRow).first);
        expect(row.strikeThroughAmount, isTrue);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.descendant(of: firstTile, matching: find.byType(ListTile)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TaskItemRow), findsNothing);
        await tester.ensureVisible(find.byType(ExpansionTile).last);
        await tester.tap(find.byType(ExpansionTile).last);
        await tester.pumpAndSettle();
        expect(find.byType(TaskItemRow), findsOneWidget);
        expect(find.text('Итого: 200.00 ₽'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final clientsMode in [true, false]) {
    testWidgets(
      'automatically loads long history in pages of 50, clients=$clientsMode',
      (tester) async {
        final repo = _Repository()
          ..automatic = true
          ..rows = 120;
        final provider = DeliveryHistoryProvider(repo);
        addTearDown(provider.dispose);
        if (!clientsMode) await provider.setClientsMode(false);
        repo.documentOffsets.clear();
        repo.documentLimits.clear();
        await tester.pumpWidget(
          _app(
            ChangeNotifierProvider.value(
              value: provider,
              child: const DeliveryHistoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          clientsMode ? provider.deliveries.length : provider.documents.length,
          50,
        );
        expect(
          find.text(
            clientsMode ? 'Доставок: 120' : 'Документов: 120',
            findRichText: true,
          ),
          findsOneWidget,
        );
        if (clientsMode) {
          expect(find.byKey(const ValueKey('0')), findsOneWidget);
        }
        for (var i = 0; i < 45; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -900));
          await tester.pumpAndSettle();
          if (!provider.hasMore) {
            break;
          }
        }
        expect(
          clientsMode ? provider.deliveries.length : provider.documents.length,
          120,
        );
        expect(
          clientsMode
              ? repo.requests.map((r) => r.offset)
              : repo.documentOffsets,
          [0, 50, 100],
        );
        expect(
          clientsMode ? repo.requests.map((r) => r.limit) : repo.documentLimits,
          everyElement(50),
        );
        expect(find.text('Показать ещё'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'toolbar fits a narrow window with enlarged text and stable filter height',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository()..automatic = true;
      final provider = DeliveryHistoryProvider(repo);
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: ChangeNotifierProvider.value(
              value: provider,
              child: const DeliveryHistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.byType(ListView));
      await provider.setClientsMode(false);
      await tester.pumpAndSettle();
      expect(
        (tester.getTopLeft(find.byType(ListView)).dy - top.dy).abs(),
        lessThan(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'history toolbar respects $brightness colors and dense search',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1640, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repository()
          ..automatic = true
          ..rows = 2;
        final provider = DeliveryHistoryProvider(repo);
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          _app(
            ChangeNotifierProvider.value(
              value: provider,
              child: const DeliveryHistoryScreen(),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final toolbar = tester.widget<Material>(
          find.byKey(const ValueKey('delivery-history-toolbar-surface')),
        );
        final colors = Theme.of(
          tester.element(
            find.byKey(const ValueKey('delivery-history-toolbar-surface')),
          ),
        ).colorScheme;
        expect(toolbar.color, colors.surfaceContainerLow);
        final toolbarRight = tester
            .getRect(
              find.byKey(const ValueKey('delivery-history-toolbar-surface')),
            )
            .right;
        expect(
          tester.widget<TextField>(find.byType(TextField)).decoration!.isDense,
          isTrue,
        );
        final clientCount = find.text('Доставок: 2', findRichText: true);
        expect(clientCount, findsOneWidget);
        expect(
          (tester.getRect(clientCount).right - (toolbarRight - 16)).abs(),
          lessThan(1),
        );
        await provider.setClientsMode(false);
        await tester.pumpAndSettle();
        expect(find.text('Документов: 2', findRichText: true), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('document shows both dates and no matched clients', (
    tester,
  ) async {
    final doc = ClientDelivery.fromJson(_json('one')).document;
    await tester.pumpWidget(
      _app(HistoryDocumentCard(document: doc, onOpen: () {})),
    );
    expect(find.text('Плановая дата: 03.11.2026'), findsOneWidget);
    expect(find.text('Создан: 02.11.2026 12:30'), findsOneWidget);
    expect(find.text('Исторический клиент'), findsNothing);
  });
  testWidgets(
    'filters stay in place and reset remains a draft until confirmed',
    (tester) async {
      final repo = _Repository()..automatic = true;
      final provider = DeliveryHistoryProvider(
        repo,
        now: () => DateTime(2026, 11, 3),
      );
      addTearDown(provider.dispose);
      await provider.setDateRange(
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
      );
      await tester.pumpWidget(
        _app(
          ChangeNotifierProvider.value(
            value: provider,
            child: const DeliveryHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Доставок: 0', findRichText: true), findsOneWidget);
      expect(
        find.text('За выбранный период записи не найдены.'),
        findsOneWidget,
      );
      final before = tester.getTopLeft(find.byType(ListView));
      final modeSelector = find.byType(SegmentedButton<bool>);
      final modeWidth = tester.getSize(modeSelector).width;
      expect(
        tester.widget<SegmentedButton<bool>>(modeSelector).showSelectedIcon,
        isFalse,
      );
      await tester.tap(find.text('Документы'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ListView)), before);
      expect(tester.getSize(modeSelector).width, modeWidth);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Документов: 0', findRichText: true), findsOneWidget);
      expect(
        find.text('За выбранный период записи не найдены.'),
        findsOneWidget,
      );
      final documentSelector = find.byType(SegmentedButton<String>);
      final documentSelectorWidth = tester.getSize(documentSelector).width;
      expect(
        tester
            .widget<SegmentedButton<String>>(documentSelector)
            .showSelectedIcon,
        isFalse,
      );
      await tester.tap(find.text('Доставки'));
      await tester.pumpAndSettle();
      expect(tester.getSize(documentSelector).width, documentSelectorWidth);
      await tester.tap(find.text('01.01.2026 — 31.01.2026'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<AppDateRangeDialog>(
        find.byType(AppDateRangeDialog),
      );
      expect(dialog.maxRangeMonths, 12);
      expect(dialog.showReset, true);
      await tester.enterText(
        find.byKey(const ValueKey('period-start')),
        '01.01.2026',
      );
      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDateRangeDialog), findsOneWidget);
      expect(provider.dateRange.start, DateTime(2026, 1, 1));
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(provider.dateRange.start, DateTime(2026, 1, 1));
      await tester.tap(find.text('01.01.2026 — 31.01.2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();
      expect(provider.dateRange.start, DateTime(2026, 1, 1));
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      final today = DateUtils.dateOnly(DateTime.now());
      expect(
        provider.dateRange.start,
        DateTime(today.year, today.month, today.day - 29),
      );
      expect(provider.dateRange.end, today);
    },
  );
}
