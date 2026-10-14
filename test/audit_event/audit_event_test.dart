import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_api_data_source.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_repo.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_screen.dart';
import 'package:provider/provider.dart';

import '../auth/auth_fakes.dart';

Map<String, dynamic> eventJson(
  String id, {
  String operation = 'save',
  String action = 'updated',
}) => {
  'eventId': id,
  'operationId': operation,
  'eventType': 'FutureEvent',
  'createdAt': '2026-10-14T10:00:00Z',
  'actor': {'actorId': 'actor-uuid', 'displayName': 'manager'},
  'action': action,
  'subject': {'type': 'product', 'id': 'product-uuid', 'displayName': 'Вода'},
  'data': <String, Object?>{},
  'changes': {
    'basePrice': {'oldValue': 100, 'newValue': 120},
    'unknownField': {
      'oldValue': null,
      'newValue': [
        true,
        {'nested': 'value'},
      ],
    },
  },
};

AuditEvent event(String id, {String operation = 'save'}) =>
    AuditEvent.fromJson(eventJson(id, operation: operation));

class Repo implements AuditLogRepository {
  final calls = <(String?, String?)>[];
  Future<AuditPage> Function(String?, String?)? load;
  @override
  Future<AuditPage> getAuditEvents({
    String? search,
    String? cursor,
    required int limit,
  }) {
    calls.add((search, cursor));
    return load?.call(search, cursor) ??
        Future.value(AuditPage(events: [event('1')]));
  }
}

void main() {
  test(
    'API uses Bearer, encoded search/cursor, dynamic JSON and nextCursor',
    () async {
      final transport = RecordingTransport();
      addTearDown(transport.close);
      final auth = AuthServiceImpl(
        repository: FakeAuthRepository(),
        tokenStorage: MemoryTokenStorage(),
      );
      addTearDown(auth.dispose);
      await auth.login(username: 'manager', password: '');
      transport.respond = (_) async => HttpTransportResponse(
        statusCode: 200,
        body: jsonEncode({
          'data': {
            'events': [eventJson('event-uuid', action: 'future_action')],
            'nextCursor': 'opaque+/=',
          },
        }),
      );
      final repo = AuditLogRepositoryImpl(
        ApiAuditLogDataSource(
          ApiClient(
            transport: transport,
            authService: auth,
            userAgent: 'audit-test',
          ),
        ),
      );
      final page = await repo.getAuditEvents(
        search: ' Иванов & Вода ',
        cursor: 'old+/=',
        limit: 50,
      );
      final request = transport.requests.single;
      final uri = Uri.parse(request.path);
      expect(uri.path, '/protected/events');
      expect(uri.queryParameters, {
        'search': 'Иванов & Вода',
        'cursor': 'old+/=',
        'limit': '50',
      });
      expect(request.headers!['Authorization'], 'Bearer original-access');
      expect(page.nextCursor, 'opaque+/=');
      expect(page.events.single.action, AuditAction.other);
      expect(page.events.single.createdAt.isUtc, isTrue);
      expect(page.events.single.changes['unknownField']!.newValue, [
        true,
        {'nested': 'value'},
      ]);
    },
  );

  test(
    'cursor pages deduplicate and merge operation split across pages',
    () async {
      final repo = Repo()
        ..load = (_, cursor) async => cursor == null
            ? AuditPage(events: [event('3'), event('2')], nextCursor: 'older')
            : AuditPage(events: [event('2'), event('1')]);
      final provider = AuditLogProvider(repo);
      addTearDown(provider.dispose);
      await provider.fetchEvents();
      expect(provider.hasMore, isTrue);
      await provider.fetchEvents();
      expect(repo.calls, [(null, null), (null, 'older')]);
      expect(provider.events.map((e) => e.eventId), ['3', '2', '1']);
      expect(provider.operations.single.events, hasLength(3));
      expect(provider.hasMore, isFalse);
    },
  );

  test('old search response cannot overwrite newer search', () async {
    final old = Completer<AuditPage>();
    final repo = Repo()
      ..load = (search, _) => search == 'old'
          ? old.future
          : Future.value(AuditPage(events: [event('new')]));
    final provider = AuditLogProvider(repo);
    addTearDown(provider.dispose);
    final pending = provider.searchEvents('old');
    await provider.searchEvents('new');
    old.complete(AuditPage(events: [event('old')], nextCursor: 'stale'));
    await pending;
    expect(provider.events.single.eventId, 'new');
    expect(provider.search, 'new');
    expect(provider.isLoadingMore, isFalse);
  });

  test('page failure keeps data and retry uses unchanged cursor', () async {
    var fail = true;
    final repo = Repo()
      ..load = (_, cursor) async {
        if (cursor == null) {
          return AuditPage(events: [event('first')], nextCursor: 'older');
        }
        if (fail) throw StateError('offline');
        return AuditPage(events: [event('last')]);
      };
    final provider = AuditLogProvider(repo);
    addTearDown(provider.dispose);
    await provider.fetchEvents();
    await provider.fetchEvents();
    expect(provider.events.single.eventId, 'first');
    expect(provider.hasError, isTrue);
    fail = false;
    await provider.fetchEvents();
    expect(repo.calls.map((call) => call.$2), [null, 'older', 'older']);
    expect(provider.events, hasLength(2));
    expect(provider.hasError, isFalse);
  });

  test('invalid cursor restarts with first page', () async {
    var requests = 0;
    final repo = Repo()
      ..load = (_, cursor) async {
        requests++;
        if (cursor != null) {
          throw const ApiException(
            statusCode: 422,
            message: 'Invalid event cursor',
          );
        }
        return AuditPage(events: [event('$requests')], nextCursor: 'older');
      };
    final provider = AuditLogProvider(repo);
    addTearDown(provider.dispose);
    await provider.fetchEvents();
    await provider.fetchEvents();
    expect(repo.calls.map((call) => call.$2), [null, 'older', null]);
    expect(provider.events.single.eventId, '3');
    expect(provider.isLoadingMore, isFalse);
  });

  testWidgets(
    'journal shows groups, Russian fields and arbitrary JSON without exception',
    (tester) async {
      final repo = Repo()
        ..load = (_, _) async => AuditPage(events: [event('2'), event('1')]);
      final provider = AuditLogProvider(repo);
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: AuditLogScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Связанные изменения · 2'), findsOneWidget);
      expect(find.textContaining('Базовая цена: 100 → 120'), findsNWidgets(2));
      expect(find.textContaining('unknownField'), findsNWidgets(2));
      expect(find.byTooltip('Обновить журнал'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
