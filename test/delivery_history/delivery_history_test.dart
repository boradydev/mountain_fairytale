import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_history/delivery_history_abcs.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/delivery_history_provider.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/delivery_history_screen.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/history_document_card.dart';
import 'package:mountain_fairytale/shared/widgets/app_date_range_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:provider/provider.dart';

class _Request {
  final DateTime from;
  final DateTime to;
  final String search;
  final bool cancelled;
  final int offset;
  final Completer<DeliveryHistoryPage> result = Completer();
  _Request(this.from, this.to, this.search, this.cancelled, this.offset);
}

class _Repository implements DeliveryHistoryRepository {
  final List<_Request> requests = [];
  bool automatic = false;
  @override
  Future<DeliveryHistoryPage> getHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String search,
    required bool includeCancelled,
    required int offset,
    required int limit,
  }) {
    final request = _Request(
      dateFrom,
      dateTo,
      search,
      includeCancelled,
      offset,
    );
    requests.add(request);
    if (automatic) {
      request.result.complete(
        const DeliveryHistoryPage(documents: [], total: 0),
      );
    }
    return request.result.future;
  }
}

HistoryDocument _document(String id, {bool pickup = false}) =>
    HistoryDocument.fromJson({
      'deliveryDocumentId': id,
      'documentType': pickup ? 'pickupSheet' : 'deliveryRouteSheet',
      'plannedDate': '2026-11-03',
      'isActive': true,
      'driverName': 'Водитель Иван',
      'carModelAndNumber': 'ГАЗ А123АА',
      'clientsCount': 4,
      'purchasesCount': 3,
      'totalAmount': '900.50',
      'matchedClients': [
        {
          'pointId': 'purchase-$id',
          'clientId': 'client',
          'clientName': 'Магазин Север',
          'address': 'Длинный адрес клиента, улица Северная, дом 123',
          'phone': '+7 (999) 123-45-67',
          'paymentMethodName': 'Наличные',
          'totalAmount': '200.00',
          'items': [
            {
              'productName': 'Историческое название товара',
              'quantity': 2,
              'price': '100.00',
              'amount': '200.00',
            },
          ],
        },
      ],
    });

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  supportedLocales: const [Locale('ru')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);

void main() {
  test(
    'last 30 calendar days, stale responses, pagination and reset',
    () async {
      final repo = _Repository();
      final provider = DeliveryHistoryProvider(
        repo,
        now: () => DateTime(2026, 11, 3, 23),
      );
      addTearDown(provider.dispose);
      expect(provider.dateRange.start, DateTime(2026, 10, 5));
      expect(provider.dateRange.end, DateTime(2026, 11, 3));
      final old = provider.refresh();
      final current = provider.setSearch('Север');
      repo.requests[1].result.complete(
        DeliveryHistoryPage(documents: [_document('new')], total: 2),
      );
      await current;
      repo.requests[0].result.complete(
        DeliveryHistoryPage(documents: [_document('old')], total: 100),
      );
      await old;
      expect(provider.documents.single.id, 'new');
      final next = provider.loadMore();
      expect(repo.requests.last.offset, 1);
      expect(repo.requests.last.search, 'Север');
      repo.requests.last.result.complete(
        DeliveryHistoryPage(documents: [_document('next')], total: 2),
      );
      await next;
      expect(provider.documents.length, 2);
      expect(provider.hasMore, isFalse);
      repo.automatic = true;
      await provider.setIncludeCancelled(true);
      expect(repo.requests.last.cancelled, isTrue);
      await provider.resetFilters();
      expect(repo.requests.last.search, '');
      expect(repo.requests.last.cancelled, isFalse);
      expect(repo.requests.last.from, DateTime(2026, 10, 5));
    },
  );

  test(
    'year limit includes leap day and rejects longer ranges before request',
    () async {
      final repo = _Repository()..automatic = true;
      final provider = DeliveryHistoryProvider(repo);
      addTearDown(provider.dispose);
      await provider.setDateRange(
        DateTimeRange(start: DateTime(2024, 2, 29), end: DateTime(2025, 2, 28)),
      );
      expect(repo.requests.length, 1);
      await expectLater(
        provider.setDateRange(
          DateTimeRange(
            start: DateTime(2024, 2, 29),
            end: DateTime(2025, 3, 1),
          ),
        ),
        throwsArgumentError,
      );
      expect(repo.requests.length, 1);
    },
  );

  test('failed page can be retried without losing previous results', () async {
    final repo = _Repository();
    final provider = DeliveryHistoryProvider(repo);
    addTearDown(provider.dispose);
    final first = provider.refresh();
    repo.requests.last.result.complete(
      DeliveryHistoryPage(documents: [_document('first')], total: 2),
    );
    await first;
    final next = provider.loadMore();
    repo.requests.last.result.completeError(Exception('offline'));
    await next;
    expect(provider.error, isNotNull);
    expect(provider.documents.single.id, 'first');
    final retry = provider.loadMore();
    expect(repo.requests.last.offset, 1);
    repo.requests.last.result.complete(
      DeliveryHistoryPage(documents: [_document('second')], total: 2),
    );
    await retry;
    expect(provider.error, isNull);
    expect(provider.documents.length, 2);
  });

  testWidgets(
    'purchase opens a detail dialog independently from document on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      await tester.pumpWidget(
        _app(
          ListView(
            children: [
              HistoryDocumentCard(
                document: _document('one'),
                onOpen: () => opened++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Клиентов: 4'), findsOneWidget);
      expect(find.text('Водитель: Водитель Иван'), findsOneWidget);
      await tester.tap(find.text('Подробнее о покупке'));
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Способ оплаты: Наличные'), findsOneWidget);
      expect(find.text('Историческое название товара'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Доставка · 03.11.2026'));
      expect(opened, 1);
    },
  );

  testWidgets('pickup card uses purchases and hides vehicle and driver', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        HistoryDocumentCard(
          document: _document('pickup', pickup: true),
          onOpen: () {},
        ),
      ),
    );
    expect(find.text('Покупок: 3'), findsOneWidget);
    expect(find.textContaining('Водитель:'), findsNothing);
    expect(find.textContaining('Машина:'), findsNothing);
  });

  testWidgets('history reuses checkbox and period dialog with year limit', (
    tester,
  ) async {
    final repo = _Repository()..automatic = true;
    final provider = DeliveryHistoryProvider(
      repo,
      now: () => DateTime(2026, 11, 3),
    );
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      _app(
        ChangeNotifierProvider.value(
          value: provider,
          child: const DeliveryHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LabeledCheckboxToggle), findsOneWidget);
    await tester.tap(find.text('05.10.2026 — 03.11.2026'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppDateRangeDialog>(find.byType(AppDateRangeDialog))
          .maxRangeMonths,
      12,
    );
    await tester.enterText(
      find.byKey(const ValueKey('period-start')),
      '01.01.2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('period-end')),
      '01.01.2027',
    );
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(find.text('Период не может превышать 12 месяцев'), findsOneWidget);
    expect(repo.requests.length, 1);
    expect(tester.takeException(), isNull);
  });
}
