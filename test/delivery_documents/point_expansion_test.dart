import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';

import 'constructors_test.dart'
    show Cars, Drivers, Routes, PrintService, Products, PaymentDirectory;
import 'document_provider_test.dart' show Clients, point;
import 'route_optimization_test.dart' show OptimizationFake;

class _PointClients extends Clients {
  @override
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives({
    bool includeDeactivated = false,
  }) async => [];
}

class _Editor {
  final geo = OptimizationFake();
  final routes = Routes();
  final clients = ClientsProvider(_PointClients());
  late final provider = RouteConstructorProvider(
    carRepo: Cars(),
    driverRepo: Drivers(),
    routeRepo: routes,
    printService: PrintService(),
    productRepo: Products(),
    paymentMethodRepo: PaymentDirectory(),
    clientRepo: Clients(),
    locationRepository: geo,
  );

  _Editor(int count) {
    routes.sheet = routes.sheet.copyWith(
      points: List.generate(
        count,
        (index) => RoutePoint(
          pointId: 'point-$index',
          clientId: 'client-$index',
          clientName: 'Клиент $index',
          address: 'Адрес $index',
          phone: 'phone-$index',
          salesRepresentative: '',
          items: point.items,
        ),
      ),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeProvider(await SharedPreferences.getInstance());
    addTearDown(theme.dispose);
    addTearDown(clients.dispose);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: clients),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DeliveryDocumentEditor(
                      provider: provider,
                      title: 'Маршрутный лист',
                      initialize: () =>
                          provider.loadExistingRouteById('document'),
                      metaBuilder: (_) => const SizedBox(height: 80),
                      save: () async => true,
                      changeActive: () async => true,
                    ),
                  ),
                ),
                child: const Text('Открыть документ'),
              ),
            ),
          ),
        ),
      ),
    );
    await open(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Открыть документ'));
    await tester.pumpAndSettle();
  }

  ScrollController controller(WidgetTester tester) => tester
      .widget<ReorderableListView>(find.byType(ReorderableListView))
      .scrollController!;
}

void main() {
  testWidgets(
    'expanded and explicitly collapsed points survive offscreen recycling',
    (tester) async {
      final editor = _Editor(30);
      await editor.mount(tester);
      await tester.tap(find.text('Клиент 0'));
      await tester.pumpAndSettle();
      expect(find.text('Телефон: phone-0'), findsOneWidget);

      var scroll = editor.controller(tester);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Клиент 0'), findsNothing);
      await tester.ensureVisible(find.text('Клиент 29'));
      await tester.tap(find.text('Клиент 29'));
      await tester.pumpAndSettle();
      final offset = scroll.offset;
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      scroll = editor.controller(tester);
      expect(scroll.offset, closeTo(offset, 0.01));
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      scroll = editor.controller(tester);
      expect(scroll.offset, closeTo(offset, 0.01));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Телефон: phone-0'), findsOneWidget);

      await tester.tap(find.text('Клиент 0'));
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Телефон: phone-0'), findsNothing);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await editor.open(tester);
      expect(editor.controller(tester).offset, 0);
      expect(find.text('Клиент 0'), findsOneWidget);
      expect(find.text('Телефон: phone-0'), findsNothing);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'expansion follows clients through mode changes, edits and reorder; reopening resets it',
    (tester) async {
      final editor = _Editor(2);
      await editor.mount(tester);
      await tester.tap(find.text('Клиент 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'enter editing');
      expect(find.text('Телефон: phone-0'), findsOneWidget);
      expect(find.text('Телефон: phone-1'), findsNothing);

      await tester.tap(find.byTooltip('Увеличить количество'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'update quantity');
      expect(find.text('Телефон: phone-0'), findsOneWidget);
      editor.provider.reorderPoints(0, 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'manual reorder');
      expect(editor.provider.points.last.clientId, 'client-0');
      expect(find.text('Телефон: phone-0'), findsOneWidget);
      expect(find.text('Телефон: phone-1'), findsNothing);

      final optimization = editor.provider.optimizeOrder();
      editor.geo.gate.complete({
        'orderedClientIds': ['client-0', 'client-1'],
      });
      await optimization;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'optimization');
      expect(editor.provider.points.first.clientId, 'client-0');
      expect(find.text('Телефон: phone-0'), findsOneWidget);
      expect(find.text('Телефон: phone-1'), findsNothing);
      editor.provider.undoOptimization();
      await tester.pumpAndSettle();
      expect(find.text('Телефон: phone-0'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'cancel editing');
      expect(find.text('Только просмотр'), findsOneWidget);
      expect(find.text('Телефон: phone-0'), findsOneWidget);
      expect(find.text('Телефон: phone-1'), findsNothing);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await editor.open(tester);
      expect(find.text('Телефон: phone-0'), findsNothing);
      expect(find.text('Телефон: phone-1'), findsNothing);
      expect(find.text('Клиент 0'), findsOneWidget);
      expect(editor.routes.saved, 0);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
