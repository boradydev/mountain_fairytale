import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/data/auth_api_data_source.dart';
import 'package:mountain_fairytale/features/auth/data/auth_repo.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_api_data_source.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_repo.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_screen.dart';
import 'package:provider/provider.dart';

import '../auth/auth_fakes.dart' show MemoryTokenStorage;

class _RealHttp extends HttpOverrides {}

void main() {
  testWidgets('actual backend events parse and render in the journal', (
    tester,
  ) async {
    final transport = HttpTransport(
      baseUrl: Platform.environment['LIVE_API_URL'] ?? 'http://127.0.0.1:8000',
      client: _RealHttp().createHttpClient(null),
    );
    final auth = AuthServiceImpl(
      repository: AuthRepositoryImpl(
        dataSource: AuthApiDataSource(transport: transport),
      ),
      tokenStorage: MemoryTokenStorage(),
    );
    final api = ApiClient(
      transport: transport,
      authService: auth,
      userAgent: 'MountainFairytale/AuditLiveCheck',
    );
    final repo = AuditLogRepositoryImpl(ApiAuditLogDataSource(api));
    final provider = AuditLogProvider(repo);
    addTearDown(() {
      provider.dispose();
      auth.dispose();
      transport.close();
    });
    final name = 'audit_live_${DateTime.now().microsecondsSinceEpoch}';
    await tester.runAsync(() async {
      await auth.login(
        username: Platform.environment['LIVE_API_USERNAME']!,
        password: Platform.environment['LIVE_API_PASSWORD']!,
      );
      final created = await api.post(
        '/protected/products/create',
        body: {'name': name, 'basePrice': 100},
      );
      final productId = (created['data'] as Map)['productId'] as String;
      await api.patch(
        '/protected/products/$productId',
        body: {'name': '$name новое', 'basePrice': 120},
      );
      await api.patch(
        '/protected/products/$productId',
        body: {'isActive': false},
      );
      final first = await repo.getAuditEvents(search: name, limit: 1);
      expect(first.events.single.action, AuditAction.deactivated);
      expect(first.nextCursor, isNotNull);
      final next = await repo.getAuditEvents(
        search: name,
        cursor: first.nextCursor,
        limit: 50,
      );
      expect(next.events.map((e) => e.action), [
        AuditAction.updated,
        AuditAction.created,
      ]);
      expect(next.events.last.data['name'], name);
      expect(next.events.last.subject.displayName, name);
      expect(next.events.first.changes['basePrice']!.oldValue, 100);
      expect(next.events.first.changes['basePrice']!.newValue, 120);
      await provider.searchEvents(name);
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: AuditLogScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Базовая цена'), findsNothing);
    expect(find.byTooltip('Деактивация'), findsOneWidget);
    final updated = provider.events.firstWhere(
      (event) => event.action == AuditAction.updated,
    );
    await tester.tap(
      find.byKey(ValueKey('audit-header-${updated.operationId}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Базовая цена'), findsOneWidget);
    expect(find.textContaining(name), findsWidgets);
    expect(provider.events, hasLength(3));
    expect(tester.takeException(), isNull);
  }, skip: Platform.environment['LIVE_AUDIT_EVENTS'] != 'true');
}
