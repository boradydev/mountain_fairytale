import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/dashboard/data/dashboard_updates_repo.dart';
import 'package:mountain_fairytale/features/dashboard/ui/dashboard_screen.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_day_list.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';

import '../auth/auth_fakes.dart';
import 'delivery_days_provider_test.dart' show DaysRepository, day;

class EmptyClients implements ClientRepository {
  @override
  Future<List<Client>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PendingUpdates extends DashboardUpdatesRepository {
  final pending = Completer<DashboardUpdates>();
  bool fail = false;
  int calls = 0;
  PendingUpdates(super.client);

  @override
  Future<DashboardUpdates> wait({
    DashboardUpdates? after,
    required HttpRequestCancellation cancellation,
  }) {
    calls++;
    if (fail) throw StateError('Notification channel unavailable');
    return pending.future;
  }
}

void main() {
  late DaysRepository repository;
  late DeliveryDaysProvider days;
  late ClientsProvider clients;
  late PendingUpdates updates;

  setUp(() {
    repository = DaysRepository()
      ..days = List.generate(21, (i) => day(DateTime(2026, 10, 23 - i)));
    days = DeliveryDaysProvider(repository);
    clients = ClientsProvider(EmptyClients());
    final auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    final transport = RecordingTransport();
    updates = PendingUpdates(
      ApiClient(transport: transport, authService: auth, userAgent: 'test'),
    );
    addTearDown(() {
      if (!updates.pending.isCompleted) {
        updates.pending.complete(
          const DashboardUpdates(
            serverId: 'test',
            version: 0,
            clientsChanged: false,
            deliveryDaysChanged: false,
            reloadRequired: false,
          ),
        );
      }
      days.dispose();
      clients.dispose();
      auth.dispose();
      transport.close();
    });
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: days),
          ChangeNotifierProvider.value(value: clients),
          Provider<DashboardUpdatesRepository>.value(value: updates),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DeliveryDaysScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  ScrollPosition daysPosition(WidgetTester tester) => tester
      .widget<ListView>(
        find
            .descendant(
              of: find.byType(DeliveryDaysListView),
              matching: find.byType(ListView),
            )
            .first,
      )
      .controller!
      .position;

  testWidgets(
    'initial lists load without waiting for dashboard notifications',
    (tester) async {
      await show(tester);
      expect(updates.calls, 1);
      expect(days.status, DeliveryStatus.success);
      expect(days.days.length, 7);
      expect(clients.status, ClientStatus.success);
      expect(find.text('Загрузить ещё'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'scrolling automatically requests seven more days without a button',
    (tester) async {
      await show(tester);
      final position = daysPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.dayCalls, [(0, 7), (7, 7)]);
      expect(days.days.length, 14);
      expect(find.text('Загрузить ещё'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('notification errors do not leave the initial spinner running', (
    tester,
  ) async {
    updates.fail = true;
    await show(tester);
    expect(days.status, DeliveryStatus.success);
    expect(clients.status, ClientStatus.success);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'failed initial data request exposes retry rather than an infinite spinner',
    (tester) async {
      repository.failDays = true;
      await show(tester);
      expect(days.status, DeliveryStatus.failure);
      expect(
        find.text('Не удалось загрузить дни доставки. Повторите запрос.'),
        findsOneWidget,
      );
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.failDays = false;
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(days.status, DeliveryStatus.success);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('repeated bottom scrolls do not duplicate an in-flight page', (
    tester,
  ) async {
    await show(tester);
    final next = Completer<DeliveryDaysPage>();
    repository.loadDays = (_, _) => next.future;
    final position = daysPosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(repository.dayCalls, [(0, 7), (7, 7)]);
    next.complete(
      DeliveryDaysPage(
        days: repository.days.skip(7).take(7).toList(),
        total: 21,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
}
