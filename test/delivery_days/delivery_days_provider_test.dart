import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/day_documents_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';

DeliveryDay day(DateTime date) => DeliveryDay(
  plannedDate: date,
  deliveryPointsCount: 0,
  pickupPointsCount: 0,
  products: [],
  totalAmount: 0,
);

class DaysRepository implements DeliveryDayRepository {
  List<DeliveryDay> days = [];
  List<RouteDocument> documents = [];
  final dayCalls = <(int, int)>[];
  final documentCalls = <(DateTime, bool)>[];
  bool failDays = false, failDocuments = false;
  Future<DeliveryDaysPage> Function(int, int)? loadDays;
  Future<List<RouteDocument>> Function(DateTime, bool)? loadDocuments;
  @override
  Future<DeliveryDaysPage> getDeliveryDays({
    required int offset,
    required int limit,
  }) async {
    dayCalls.add((offset, limit));
    if (loadDays != null) return loadDays!(offset, limit);
    if (failDays) throw StateError('Offline');
    return DeliveryDaysPage(
      days: days.skip(offset).take(limit).toList(),
      total: days.length,
    );
  }

  @override
  Future<List<RouteDocument>> getDayDocuments(
    DateTime date, {
    bool includeCancelled = false,
  }) async {
    documentCalls.add((date, includeCancelled));
    if (loadDocuments != null) return loadDocuments!(date, includeCancelled);
    if (failDocuments) throw StateError('Offline');
    return documents
        .where(
          (document) =>
              document.date == date && (includeCancelled || document.isActive),
        )
        .toList();
  }
}

void main() {
  test('calendar pagination uses total, refresh replaces loaded range after date moves', () async {
    final repo = DaysRepository()
      ..days = List.generate(14, (i) => day(DateTime(2026, 10, 20 - i)));
    final p = DeliveryDaysProvider(repo);
    addTearDown(p.dispose);
    await p.fetchDeliveryDays();
    expect(p.days.length, 7);
    expect(p.hasMore, isTrue);
    await p.fetchDeliveryDays();
    expect(repo.dayCalls, [(0, 7), (7, 7)]);
    expect(p.hasMore, isFalse);
    await p.fetchDeliveryDays();
    expect(repo.dayCalls.length, 2);
    repo.days = [day(DateTime(2026, 10, 1)), day(DateTime(2026, 9, 30))];
    await p.refreshDeliveryDays();
    expect(repo.dayCalls.last, (0, 14));
    expect(p.days, repo.days);
    expect(p.total, 2);
    expect(p.hasMore, isFalse);
  });
  test(
    'failed refresh keeps cards and total and can retry successfully',
    () async {
      final repo = DaysRepository()..days = [day(DateTime(2026))];
      final p = DeliveryDaysProvider(repo);
      addTearDown(p.dispose);
      await p.fetchDeliveryDays();
      repo.failDays = true;
      await p.refreshDeliveryDays();
      expect(p.days.single.plannedDate, DateTime(2026));
      expect(p.total, 1);
      expect(p.hasError, isTrue);
      repo.failDays = false;
      await p.refreshDeliveryDays();
      expect(p.hasError, isFalse);
    },
  );
  test('new refresh supersedes an in-flight pagination response', () async {
    final repo = DaysRepository();
    final old = Completer<DeliveryDaysPage>();
    repo.loadDays = (_, _) => old.future;
    final p = DeliveryDaysProvider(repo);
    addTearDown(p.dispose);
    final pending = p.fetchDeliveryDays();
    repo.loadDays = (_, _) async =>
        DeliveryDaysPage(days: [day(DateTime(2026, 10, 18))], total: 1);
    await p.refreshDeliveryDays();
    old.complete(DeliveryDaysPage(days: [day(DateTime(2025))], total: 200));
    await pending;
    expect(p.days.single.plannedDate, DateTime(2026, 10, 18));
    expect(p.total, 1);
  });
  test('empty calendar succeeds without generating today', () async {
    final p = DeliveryDaysProvider(DaysRepository());
    addTearDown(p.dispose);
    await p.fetchDeliveryDays();
    expect(p.days, isEmpty);
    expect(p.isEmpty, isTrue);
    expect(p.hasMore, isFalse);
  });
  test('dialog loads all rows, filters cancelled and ignores stale filter response', () async {
    final repo = DaysRepository();
    final date = DateTime(2026, 10, 18);
    final old = Completer<List<RouteDocument>>();
    repo.loadDocuments = (_, _) => old.future;
    final p = DayDocumentsProvider(repo, date);
    addTearDown(p.dispose);
    final pending = p.load();
    final cancelled = PickupSheet(
      id: 'cancelled',
      date: date,
      isActive: false,
      points: [],
    );
    repo.loadDocuments = (_, _) async => [cancelled];
    await p.setIncludeCancelled(true);
    old.complete([]);
    await pending;
    expect(p.documents, [cancelled]);
    expect(p.includeCancelled, isTrue);
    expect(repo.documentCalls, [(date, false), (date, true)]);
    repo.loadDocuments = null;
    repo.failDocuments = true;
    await p.load();
    expect(p.error, isNotNull);
    expect(p.documents, [cancelled]);
    repo.failDocuments = false;
    repo.documents = [cancelled];
    await p.load();
    expect(p.error, isNull);
    expect(p.documents, [cancelled]);
    expect(p.date, date);
  });
}
