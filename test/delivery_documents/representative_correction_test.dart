import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/point_representative_selector.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';

import 'constructors_test.dart' as fixtures;
import 'document_provider_test.dart' show Clients, point;

class _Clients extends Clients {
  int updates = 0;
  @override
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives({
    bool includeDeactivated = false,
  }) async => [ClientDirectoryEntry('rep', 'Представитель')];

  @override
  Future<Client> updateClient(String id, UpdateClientRequest request) async {
    updates++;
    return Client(
      id: id,
      name: 'Клиент',
      phone: '123',
      address: 'Адрес',
      sleepingThresholdDays: 7,
      createdAt: DateTime(2026),
      isActive: true,
      salesRepresentativeId: request.salesRepresentativeId as String,
      salesRepresentativeName: 'Представитель',
    );
  }
}

class _Routes extends fixtures.Routes {
  bool fail = false;
  Map<String, dynamic>? request;
  @override
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet value) async {
    request = value.toRequestJson();
    if (fail) throw StateError('save failed');
    return super.saveRouteSheet(value);
  }
}

RouteConstructorProvider _provider(_Routes routes, _Clients clients) =>
    RouteConstructorProvider(
      carRepo: fixtures.Cars(),
      driverRepo: fixtures.Drivers(),
      routeRepo: routes,
      printService: fixtures.PrintService(),
      productRepo: fixtures.Products(),
      paymentMethodRepo: fixtures.PaymentDirectory(),
      clientRepo: clients,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saved empty point stays editable until confirmed server save', (
    tester,
  ) async {
    final clients = _Clients();
    final directory = ClientsProvider(clients);
    final routes = _Routes();
    final original = RoutePoint.fromJson({
      ...point.toJson(),
      'pointId': 'saved-point',
      'salesRepresentativeId': null,
      'salesRepresentativeName': null,
    });
    routes.sheet = DeliveryRouteSheet.fromJson({
      ...routes.sheet.toJson(),
      'points': [original.toJson()],
    });
    final p = _provider(routes, clients);
    addTearDown(p.dispose);
    addTearDown(directory.dispose);
    await p.loadExistingRouteById('document');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: directory,
        child: MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: p,
              builder: (_, _) => PointRepresentativeSelector(
                provider: p,
                point: p.points.single,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    AppDropdown<ClientDirectoryEntry> dropdown() =>
        tester.widget(find.byType(AppDropdown<ClientDirectoryEntry>));
    expect(dropdown().enabled, isFalse);
    expect(await p.beginEditing(), isTrue);
    await tester.pumpAndSettle();
    expect(dropdown().enabled, isTrue);
    expect(
      await p.selectPointRepresentative(
        p.points.single.clientId!,
        ClientDirectoryEntry('rep', 'Представитель'),
        directory,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(dropdown().enabled, isTrue);
    expect(clients.updates, 0);
    expect(
      p.points.single.toRequestJson(creating: false)['salesRepresentativeId'],
      'rep',
    );
    expect(
      await p.selectPointRepresentative(
        p.points.single.clientId!,
        ClientDirectoryEntry('other', 'Другой'),
        directory,
      ),
      isTrue,
    );
    expect(p.points.single.salesRepresentativeId, 'other');
    // Other point edits must preserve the pending correction.
    p.setPointMemo(0, 'memo');
    expect(p.points.single.representativeCorrectionPending, isTrue);
    routes.fail = true;
    expect(await p.saveRoute(), isFalse);
    expect(routes.sheet.points.single.salesRepresentativeId, isNull);
    expect(p.points.single.representativeCorrectionPending, isTrue);
    expect(clients.updates, 0);
    routes.fail = false;
    expect(await p.saveRoute(), isTrue);
    expect(
      (routes.request!['points'] as List).single['salesRepresentativeId'],
      'other',
    );
    await tester.pumpAndSettle();
    expect(dropdown().enabled, isFalse);
    expect(p.points.single.representativeCorrectionPending, isFalse);
    expect(
      p.points.single
          .toRequestJson(creating: false)
          .containsKey('salesRepresentativeId'),
      isFalse,
    );
    expect(
      await p.selectPointRepresentative(
        p.points.single.clientId!,
        ClientDirectoryEntry('rep', 'Представитель'),
        directory,
      ),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    await p.closeDocument();
  });

  test(
    'cancelling discards the pending correction without updating the client',
    () async {
      final clients = _Clients();
      final directory = ClientsProvider(clients);
      final routes = _Routes();
      routes.sheet = DeliveryRouteSheet.fromJson({
        ...routes.sheet.toJson(),
        'points': [
          {
            ...point.toJson(),
            'pointId': 'saved',
            'salesRepresentativeId': null,
          },
        ],
      });
      final p = _provider(routes, clients);
      addTearDown(p.dispose);
      addTearDown(directory.dispose);
      await p.loadExistingRouteById('document');
      expect(await p.beginEditing(), isTrue);
      expect(
        await p.selectPointRepresentative(
          p.points.single.clientId!,
          const ClientDirectoryEntry('rep', 'Имя'),
          directory,
        ),
        isTrue,
      );
      expect(await p.cancelEditing(), isTrue);
      expect(p.points.single.salesRepresentativeId, isNull);
      expect(p.points.single.representativeCorrectionPending, isFalse);
      expect(clients.updates, 0);
      expect(routes.saved, 0);
      await p.closeDocument();
    },
  );

  test(
    'new point updates client immediately and never sends correction field',
    () async {
      final clients = _Clients();
      final directory = ClientsProvider(clients);
      final p = _provider(_Routes(), clients);
      addTearDown(p.dispose);
      addTearDown(directory.dispose);
      p.resetForm();
      p.points = [
        RoutePoint.fromJson({...point.toJson(), 'pointId': null}),
      ];
      expect(
        await p.selectPointRepresentative(
          p.points.single.clientId!,
          ClientDirectoryEntry('rep', 'Представитель'),
          directory,
        ),
        isTrue,
      );
      expect(clients.updates, 1);
      expect(p.points.single.salesRepresentativeId, 'rep');
      expect(
        p.points.single
            .toRequestJson(creating: true)
            .containsKey('salesRepresentativeId'),
        isFalse,
      );
      expect(
        await p.selectPointRepresentative(
          p.points.single.clientId!,
          ClientDirectoryEntry('inactive', 'Неактивен', isActive: false),
          directory,
        ),
        isFalse,
      );
      expect(clients.updates, 1);
    },
  );

  test(
    'copy and server decoding preserve the draft versus saved distinction',
    () {
      final original = RoutePoint.fromJson({
        ...point.toJson(),
        'pointId': 'saved',
        'salesRepresentativeId': null,
      });
      final pending = original.copyWith(
        salesRepresentativeId: 'rep',
        salesRepresentative: 'Имя',
        representativeCorrectionPending: true,
      );
      expect(
        pending
            .copyWith(items: [])
            .toRequestJson(creating: false)['salesRepresentativeId'],
        'rep',
      );
      final saved = RoutePoint.fromJson(pending.toJson());
      expect(saved.representativeCorrectionPending, isFalse);
      expect(saved.salesRepresentativeId, 'rep');
    },
  );
}
