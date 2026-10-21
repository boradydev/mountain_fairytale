import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_optimization_dialog.dart';

import 'constructors_test.dart' show Cars, Drivers, Routes, PrintService;
import 'document_provider_test.dart' show Catalog, Clients, Payments, point;
import 'route_optimization_test.dart' show OptimizationFake, second;

void main() {
  testWidgets('closing calculation keeps result and undo on reopening', (
    tester,
  ) async {
    final geo = OptimizationFake();
    final routes = Routes();
    final provider = RouteConstructorProvider(
      carRepo: Cars(),
      driverRepo: Drivers(),
      routeRepo: routes,
      printService: PrintService(),
      productRepo: Catalog(),
      paymentMethodRepo: Payments(),
      clientRepo: Clients(),
      locationRepository: geo,
    )..points = [point, second];
    addTearDown(provider.dispose);
    provider.notifyListeners();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showRouteOptimizationDialog(context, provider: provider),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Точек доставки: 2'), findsOneWidget);
    await tester.tap(find.text('Оптимизировать порядок'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(provider.optimizing, isTrue);
    geo.gate.complete({
      'orderedClientIds': ['second', 'client'],
    });
    await tester.pumpAndSettle();
    expect(provider.points, [second, point]);
    expect(routes.saved, 0);
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Отменить перестановку'));
    await tester.pumpAndSettle();
    expect(provider.points, [point, second]);
    expect(provider.canUndoOptimization, isFalse);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
  });
}
