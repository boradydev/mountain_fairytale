import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_dialog.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/shared/widgets/document_summary_card.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';

import 'delivery_days_provider_test.dart' show DaysRepository;

void main() {
  final date = DateTime(2026, 11, 5);
  late DaysRepository repo;
  late DeliveryDaysProvider days;
  late List<Completer<List<RouteDocument>>> requests;
  late Completer<bool?> opening;
  var opens = 0;
  final slot = find.byKey(const ValueKey('day-documents-loading-slot'));
  final filter = find.byType(LabeledCheckboxToggle);

  DeliveryRouteSheet route(String driver) => DeliveryRouteSheet(
    id: driver,
    date: date,
    driverName: driver,
    carId: 'car',
    carModelAndNumber: 'Машина',
    startMileage: 0,
    points: [],
  );

  setUp(() {
    requests = [];
    opens = 0;
    opening = Completer<bool?>();
    repo = DaysRepository()
      ..loadDocuments = (_, _) {
        final request = Completer<List<RouteDocument>>();
        requests.add(request);
        return request.future;
      };
    days = DeliveryDaysProvider(repo);
  });
  tearDown(() => days.dispose());

  Future<void> show(WidgetTester tester, {double width = 1100}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DayDocumentsDialog(
            date: date,
            daysProvider: days,
            openDocument: (_, _, _, _, _) {
              opens++;
              return opening.future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<Rect> geometry(WidgetTester tester) => [
    tester.getRect(slot),
    tester.getRect(find.byType(Dialog)),
    tester.getRect(find.byType(ListView)),
    tester.getRect(find.text('Добавить доставку')),
    tester.getRect(find.text('Добавить самовывоз')),
    tester.getRect(find.text('Закрыть')),
  ];

  for (final width in [380.0, 1100.0]) {
    testWidgets('loading slot and dialog geometry stay fixed at width $width', (
      tester,
    ) async {
      await show(tester, width: width);
      final before = geometry(tester);
      expect(tester.getSize(slot).height, 3);
      expect(
        tester.getSize(slot).width,
        tester.getSize(find.byType(ListView)).width,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('На эту дату нет активных документов'), findsNothing);
      expect(tester.takeException(), isNull);
      requests[0].complete([]);
      await tester.pumpAndSettle();
      expect(geometry(tester), before);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('На эту дату нет активных документов'), findsOneWidget);
      await tester.tap(filter);
      await tester.pump();
      expect(geometry(tester), before);
      expect(find.text('На эту дату нет документов'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      requests[1].complete([]);
      await tester.pumpAndSettle();
      expect(find.text('На эту дату нет документов'), findsOneWidget);
      expect(geometry(tester), before);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'refresh retains cards, blocks opening, then replaces cards without moving controls',
    (tester) async {
      await show(tester);
      requests[0].complete([route('Старый водитель')]);
      await tester.pumpAndSettle();
      final before = geometry(tester);
      final card = find.byType(DocumentSummaryCard);
      final cardRect = tester.getRect(card);
      await tester.tap(filter);
      await tester.pump();
      expect(find.text('Старый водитель'), findsOneWidget);
      expect(tester.getRect(card), cardRect);
      expect(tester.widget<DocumentSummaryCard>(card).onOpen, isNull);
      await tester.tap(card);
      await tester.pump();
      expect(opens, 0);
      expect(geometry(tester), before);
      requests[1].complete([route('Новый водитель')]);
      await tester.pumpAndSettle();
      expect(find.text('Старый водитель'), findsNothing);
      expect(find.text('Новый водитель'), findsOneWidget);
      expect(geometry(tester), before);
      await tester.tap(card);
      await tester.pump();
      expect(opens, 1);
      expect(tester.widget<DocumentSummaryCard>(card).onOpen, isNull);
      await tester.tap(card);
      await tester.pump();
      expect(opens, 1);
      opening.complete(false);
      await tester.pumpAndSettle();
      expect(repo.dayCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initial error ends loading and retry displays documents', (
    tester,
  ) async {
    await show(tester);
    final before = geometry(tester);
    requests[0].completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(geometry(tester), before);
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    requests[1].complete([route('После повтора')]);
    await tester.pumpAndSettle();
    expect(find.text('После повтора'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
    expect(geometry(tester), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed refresh preserves cards during error and subsequent retry',
    (tester) async {
      await show(tester, width: 380);
      requests[0].complete([route('Сохранённый водитель')]);
      await tester.pumpAndSettle();
      final before = geometry(tester);
      await tester.tap(filter);
      await tester.pump();
      requests[1].completeError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(find.text('Сохранённый водитель'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(geometry(tester), before);
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(find.text('Сохранённый водитель'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<DocumentSummaryCard>(find.byType(DocumentSummaryCard))
            .onOpen,
        isNull,
      );
      requests[2].complete([route('Обновлённый водитель')]);
      await tester.pumpAndSettle();
      expect(find.text('Сохранённый водитель'), findsNothing);
      expect(find.text('Обновлённый водитель'), findsOneWidget);
      expect(geometry(tester), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid filter changes ignore an outdated response', (
    tester,
  ) async {
    await show(tester);
    requests[0].complete([route('Исходный водитель')]);
    await tester.pumpAndSettle();
    await tester.tap(filter);
    await tester.pump();
    await tester.tap(filter);
    await tester.pump();
    expect(repo.documentCalls, [(date, false), (date, true), (date, false)]);
    requests[2].complete([route('Актуальный ответ')]);
    await tester.pumpAndSettle();
    requests[1].complete([route('Устаревший ответ')]);
    await tester.pumpAndSettle();
    expect(find.text('Актуальный ответ'), findsOneWidget);
    expect(find.text('Устаревший ответ'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
