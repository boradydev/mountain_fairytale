import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/client_list.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';

Client row(int id) => Client(
  id: '$id',
  name: 'Клиент $id',
  phone: '+79123456789',
  address: 'Адрес',
  sleepingThresholdDays: 10,
  createdAt: DateTime(2026),
  isActive: true,
);

typedef PageRequest = ({
  int offset,
  int limit,
  String mode,
  String? search,
  bool inactive,
});

class Pages implements ClientRepository {
  final calls = <PageRequest>[];
  List<Client> rows = List.generate(61, row);
  Future<ClientsPage<Client>> Function(PageRequest)? load;
  int directoryCalls = 0;
  @override
  Future<ClientsPage<Client>> getClientsPage({
    int offset = 0,
    int limit = 25,
    String? search,
    bool includeDeactivated = false,
    String mode = 'database',
  }) async {
    final request = (
      offset: offset,
      limit: limit,
      mode: mode,
      search: search,
      inactive: includeDeactivated,
    );
    calls.add(request);
    if (load != null) return load!(request);
    return ClientsPage(rows.skip(offset).take(limit).toList(), rows.length);
  }

  @override
  Future<List<Client>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  }) async {
    directoryCalls++;
    return rows;
  }

  @override
  Future<Client> updateCooldown(String clientId, DateTime until) async {
    rows = rows.where((row) => row.id != clientId).toList();
    return row(int.parse(clientId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Pages repo;
  late ClientsProvider provider;
  setUp(() {
    repo = Pages();
    provider = ClientsProvider(repo);
  });
  tearDown(() => provider.dispose());

  test('25 per page, no concurrent duplicates, stop at total; directory stays complete', () async {
    await provider.initializeDashboardClients();
    expect(provider.dashboard.clients.length, 25);
    expect(repo.directoryCalls, 0);
    final gate = Completer<ClientsPage<Client>>();
    repo.load = (_) => gate.future;
    final next = provider.loadDashboardClients();
    await provider.loadDashboardClients();
    expect(repo.calls.map((call) => call.offset), [0, 25]);
    gate.complete(
      ClientsPage([repo.rows[24], ...repo.rows.skip(26).take(24)], 61),
    );
    await next;
    expect(provider.dashboard.clients.map((c) => c.id).toSet().length, 49);
    repo.load = null;
    await provider.loadDashboardClients();
    await provider.loadDashboardClients();
    expect(repo.calls.map((call) => call.offset), [0, 25, 50]);
    expect(provider.dashboard.hasMore, isFalse);
    expect(await provider.searchClients(''), hasLength(61));
    await provider.fetchClients();
    expect(provider.clients, hasLength(61));
  });

  test(
    'next-page failure preserves rows and retries the failed offset',
    () async {
      await provider.initializeDashboardClients();
      repo.load = (_) async => throw StateError('offline');
      await provider.loadDashboardClients();
      expect(provider.dashboard.clients.length, 25);
      expect(provider.dashboard.error, isNotEmpty);
      repo.load = null;
      await provider.loadDashboardClients();
      expect(provider.dashboard.clients.length, 50);
      expect(repo.calls.map((r) => r.offset), [0, 25, 25]);
    },
  );

  test(
    'mode caches, search, filter and stale responses are independent',
    () async {
      await provider.initializeDashboardClients();
      await provider.loadDashboardClients();
      provider.dashboard.scrollOffset = 123;
      provider.setListMode(ClientListMode.followUp);
      await Future<void>.delayed(Duration.zero);
      expect(provider.dashboard.clients.length, 25);
      provider.setListMode(ClientListMode.database);
      expect(provider.dashboard.clients.length, 50);
      expect(provider.dashboard.scrollOffset, 123);
      expect(repo.calls.length, 3);
      final old = Completer<ClientsPage<Client>>();
      repo.load = (request) => request.search == 'старый'
          ? old.future
          : Future.value(ClientsPage([row(99)], 1));
      final obsolete = provider.setSearch('старый');
      await provider.setSearch('новый');
      old.complete(ClientsPage([row(88)], 1));
      await obsolete;
      expect(provider.dashboard.clients.single.id, '99');
      provider.setListMode(ClientListMode.followUp);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls.last.mode, 'follow_up');
      expect(repo.calls.last.search, 'новый');
      await provider.setShowDeactivated(true);
      provider.setListMode(ClientListMode.database);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls.last.inactive, isTrue);
      expect(provider.dashboard.offset, 1);
    },
  );

  test(
    'refresh preserves loaded volume and scroll; failure is not acknowledged',
    () async {
      await provider.initializeDashboardClients();
      await provider.loadDashboardClients();
      provider.dashboard.scrollOffset = 400;
      repo.calls.clear();
      expect(await provider.refreshDashboardClients(), isTrue);
      expect(repo.calls.map((call) => call.offset), [0, 25]);
      expect(provider.dashboard.clients.length, 50);
      expect(provider.dashboard.scrollOffset, 400);
      repo.load = (request) async {
        if (request.offset == 25) throw StateError('offline');
        return ClientsPage([row(999), ...repo.rows.take(24)], 61);
      };
      expect(await provider.refreshDashboardClients(), isFalse);
      expect(provider.dashboard.clients.first.id, '0');
      expect(provider.dashboard.clients.length, 50);
      repo.load = null;
      expect(await provider.refreshDashboardClients(), isTrue);
      expect(repo.directoryCalls, 0);
    },
  );

  test(
    'cooldown reloads server order and removes an ineligible client',
    () async {
      await provider.initializeDashboardClients();
      provider.setListMode(ClientListMode.followUp);
      await Future<void>.delayed(Duration.zero);
      expect(await provider.updateClientCooldown('0', 1), isTrue);
      expect(provider.dashboard.clients.any((row) => row.id == '0'), isFalse);
      expect(provider.dashboard.clients.length, 25);
    },
  );

  test('a query change invalidates an in-flight background refresh', () async {
    await provider.initializeDashboardClients();
    final old = Completer<ClientsPage<Client>>();
    repo.load = (request) => request.search == ''
        ? old.future
        : Future.value(ClientsPage([row(99)], 1));
    final refreshing = provider.refreshDashboardClients();
    await provider.setSearch('new');
    old.complete(ClientsPage([row(88)], 1));
    expect(await refreshing, isFalse);
    expect(provider.dashboard.clients.single.id, '99');
  });

  for (final viewportHeight in [900.0, 20000.0]) {
    testWidgets(
      'scroll loading and viewport filling at height $viewportHeight',
      (tester) async {
        tester.view.physicalSize = Size(1200, viewportHeight);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await provider.initializeDashboardClients();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: const MaterialApp(
              home: Scaffold(body: ClientsAttentionListView()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (viewportHeight == 900) {
          expect(provider.dashboard.clients.length, 25);
          final list = tester.widget<ListView>(find.byType(ListView).first);
          list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(provider.dashboard.clients.length, 50);
          provider.setListMode(ClientListMode.followUp);
          await tester.pumpAndSettle();
          provider.setListMode(ClientListMode.database);
          await tester.pumpAndSettle();
          expect(list.controller!.offset, greaterThan(0));
        } else {
          expect(provider.dashboard.clients.length, 61);
          expect(provider.dashboard.hasMore, isFalse);
          expect(repo.calls.map((call) => call.offset), [0, 25, 50]);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final size in [
    const Size(1400, 900),
    const Size(420, 700),
    const Size(320, 420),
  ]) {
    testWidgets('stable toolbar, debounce and no overflow at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repo.rows = [];
      await provider.initializeDashboardClients();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(size.width < 500 ? 2 : 1),
              ),
              child: const Scaffold(body: ClientsAttentionListView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final position = tester.getTopLeft(field);
      final fieldSize = tester.getSize(field);
      if (size.width >= 1000) {
        expect(
          tester.getTopLeft(find.byType(LabeledCheckboxToggle)).dx,
          greaterThan(tester.getTopRight(field).dx),
        );
      }
      final height = tester.getSize(find.byType(IndexedStack)).height;
      final segments = tester.widget<SegmentedButton<ClientListMode>>(
        find.byType(SegmentedButton<ClientListMode>),
      );
      expect(segments.showSelectedIcon, isFalse);
      provider.setListMode(ClientListMode.followUp);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(field), position);
      expect(tester.getSize(field), fieldSize);
      expect(tester.getSize(find.byType(IndexedStack)).height, height);
      final visibility = tester.widget<Visibility>(
        find
            .ancestor(
              of: find.byType(LabeledCheckboxToggle),
              matching: find.byType(Visibility),
            )
            .first,
      );
      expect(visibility.visible, isFalse);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Иванов');
      await tester.pump(const Duration(milliseconds: 349));
      expect(provider.search, '');
      await tester.pump(const Duration(milliseconds: 1));
      expect(provider.search, 'Иванов');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
