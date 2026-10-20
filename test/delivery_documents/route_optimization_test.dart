import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';

import 'constructors_test.dart' show Cars, Drivers, Routes, PrintService;
import 'document_provider_test.dart' show Catalog, Clients, Payments, point;

class OptimizationFake implements LocationRepository {
  Completer<Map<String, dynamic>> gate = Completer();
  @override
  Future<Map<String, dynamic>> optimize(List<String> ids) => gate.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const second = RoutePoint(
  pointId: 'second-point',
  clientId: 'second',
  clientName: 'Другой клиент',
  address: 'Другой адрес',
  phone: '123',
  salesRepresentative: '',
  items: [],
);

void main() {
  late RouteConstructorProvider p;
  late OptimizationFake geo;
  setUp(() {
    geo = OptimizationFake();
    p = RouteConstructorProvider(
      carRepo: Cars(),
      driverRepo: Drivers(),
      routeRepo: Routes(),
      printService: PrintService(),
      productRepo: Catalog(),
      paymentMethodRepo: Payments(),
      clientRepo: Clients(),
      locationRepository: geo,
    )..points = [point, second];
    p.notifyListeners();
  });
  tearDown(() => p.dispose());
  test('missing coordinates message names clients and leaves manual reorder available', () async {
    final future = p.optimizeOrder();
    geo.gate.completeError(
      const ApiException(
        statusCode: 422,
        message:
            'Не подтверждено местоположение: Первый клиент, Второй клиент.',
      ),
    );
    await future;
    expect(p.optimizationMessage, contains('Первый клиент, Второй клиент'));
    expect(p.optimizationFailed, isTrue);
    expect(p.points, [point, second]);
    p.reorderPoints(0, 2);
    expect(p.points.first, second);
  });
  test('reordering and undo preserve point identity and goods', () async {
    final future = p.optimizeOrder();
    expect(p.canSave, isFalse);
    geo.gate.complete({
      'orderedClientIds': ['second', 'client'],
    });
    await future;
    expect(identical(p.points.last, point), isTrue);
    expect(p.points.last.items, point.items);
    expect(p.canUndoOptimization, isTrue);
    p.undoOptimization();
    expect(identical(p.points.first, point), isTrue);
    expect(p.canUndoOptimization, isFalse);
  });
  test(
    'response is discarded after manual reorder even if order is restored',
    () async {
      final future = p.optimizeOrder();
      p.reorderPoints(0, 2);
      p.reorderPoints(0, 2);
      geo.gate.complete({
        'orderedClientIds': ['second', 'client'],
      });
      await future;
      expect(p.points.first.clientId, 'client');
      expect(p.optimizationFailed, isTrue);
    },
  );
  test('partial result leaves all points unchanged', () async {
    final future = p.optimizeOrder();
    geo.gate.complete({
      'orderedClientIds': ['client'],
    });
    await future;
    expect(p.points, [point, second]);
    expect(p.optimizationFailed, isTrue);
  });
  test('result from an earlier document session is discarded', () async {
    final future = p.optimizeOrder();
    p.resetForm();
    geo.gate.complete({
      'orderedClientIds': ['second', 'client'],
    });
    await future;
    expect(p.points, isEmpty);
    expect(p.optimizing, isFalse);
  });
}
