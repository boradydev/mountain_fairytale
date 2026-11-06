import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/document_connection_dialog.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';

import 'document_provider_test.dart' show Orders, Catalog, Locks, point;

const serverError = ApiException(statusCode: 500, message: 'temporary');

class ScriptedLocks extends Locks {
  final checks = <Object?>[];
  final renewals = <Object?>[];
  Completer<void>? checkGate;
  Completer<String>? renewGate;
  int checked = 0;
  @override
  Future<void> checkConnection() async {
    checked++;
    if (checkGate != null) await checkGate!.future;
    final error = checks.isEmpty ? null : checks.removeAt(0);
    if (error != null) throw error;
  }

  @override
  Future<String> renewEditLock(String id) async {
    renewed++;
    if (renewGate != null) return renewGate!.future;
    final error = renewals.isEmpty ? null : renewals.removeAt(0);
    if (error != null) throw error;
    return 'manager';
  }
}

void main() {
  for (final error in [
    const SocketException('offline'),
    const HttpException('connection closed'),
    TimeoutException('timeout'),
    serverError,
    const ApiException(statusCode: 502, message: 'gateway'),
    const ApiException(statusCode: 503, message: 'unavailable'),
    const ApiException(statusCode: 504, message: 'timeout'),
  ]) {
    for (final failures in [1, 2, 3]) {
      testWidgets('$error: $failures background failures', (tester) async {
        final locks = ScriptedLocks()
          ..checks.addAll(List.filled(failures, error));
        final p = Orders(Catalog(), locks)..initializeDocumentSession();
        await tester.pumpWidget(ProviderLifetime(provider: p));
        var notifications = 0;
        p.addListener(() => notifications++);
        p.startConnectionWatch();
        await tester.pump(const Duration(seconds: 5));
        expect(locks.checked, 1);
        expect(p.connectionInterrupted, isFalse);
        expect(notifications, 0);
        await tester.pump(const Duration(milliseconds: 499));
        expect(locks.checked, 1);
        await tester.pump(const Duration(milliseconds: 1));
        expect(locks.checked, 2);
        await tester.pump(const Duration(milliseconds: 1499));
        expect(locks.checked, 2);
        await tester.pump(const Duration(milliseconds: 1));
        expect(locks.checked, failures == 1 ? 2 : 3);
        expect(p.connectionInterrupted, failures == 3);
        expect(p.canSave, failures != 3);
        expect(notifications, failures == 3 ? 1 : 0);
        expect(p.documentError, isNull);
        if (failures == 3) {
          expect(
            p.connectionIssue,
            error is ApiException
                ? DocumentConnectionIssue.server
                : DocumentConnectionIssue.network,
          );
          p.stopConnectionWatch();
          await tester.pumpWidget(
            ProviderLifetime(
              provider: p,
              child: MaterialApp(home: DocumentConnectionDialog(provider: p)),
            ),
          );
          expect(
            find.text(
              error is ApiException
                  ? 'Не удаётся проверить состояние сервера'
                  : 'Нет связи с сервером',
            ),
            findsOneWidget,
          );
          expect(find.byType(SnackBar), findsNothing);
        }
      });
    }
  }

  for (final errors in [
    [
      const SocketException('offline'),
      serverError,
      const SocketException('offline'),
    ],
    [
      serverError,
      const SocketException('offline'),
      const ApiException(statusCode: 503, message: 'busy'),
    ],
  ]) {
    testWidgets(
      'mixed failures retain evidence of a responding server: $errors',
      (tester) async {
        final locks = ScriptedLocks()..checks.addAll(errors);
        final p = Orders(Catalog(), locks)..initializeDocumentSession();
        await tester.pumpWidget(ProviderLifetime(provider: p));
        p.startConnectionWatch();
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 1500));
        expect(p.connectionInterrupted, isTrue);
        expect(p.connectionIssue, DocumentConnectionIssue.server);
      },
    );
  }

  for (final status in [400, 401, 403, 404, 409, 422, 423]) {
    testWidgets('HTTP $status is not retried as a transient failure', (
      tester,
    ) async {
      final locks = ScriptedLocks()
        ..checks.add(ApiException(statusCode: status, message: 'business'));
      final p = Orders(Catalog(), locks)..initializeDocumentSession();
      await tester.pumpWidget(ProviderLifetime(provider: p));
      p.startConnectionWatch();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
      expect(locks.checked, 1);
      expect(p.connectionInterrupted, [403, 409, 423].contains(status));
      if (!p.connectionInterrupted) expect(p.documentError, isNotNull);
    });
  }

  testWidgets('slow checks do not overlap periodic ticks', (tester) async {
    final locks = ScriptedLocks()..checkGate = Completer<void>();
    final p = Orders(Catalog(), locks)..initializeDocumentSession();
    await tester.pumpWidget(ProviderLifetime(provider: p));
    p.startConnectionWatch();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 20));
    expect(locks.checked, 1);
    locks.checkGate!.complete();
    await tester.pump();
    expect(p.connectionInterrupted, isFalse);
  });

  for (final action in ['close', 'session', 'dispose']) {
    for (final duringRequest in [true, false]) {
      testWidgets(
        '$action ignores old check ${duringRequest ? 'response' : 'retry delay'}',
        (tester) async {
          final locks = ScriptedLocks()..checks.add(serverError);
          if (duringRequest) locks.checkGate = Completer<void>();
          final p = Orders(Catalog(), locks)..initializeDocumentSession();
          if (action != 'dispose') {
            await tester.pumpWidget(ProviderLifetime(provider: p));
          }
          p.startConnectionWatch();
          await tester.pump(const Duration(seconds: 5));
          if (action == 'close') await p.closeDocument();
          if (action == 'session') p.initializeDocumentSession();
          if (action == 'dispose') p.dispose();
          var notifications = 0;
          if (action != 'dispose') p.addListener(() => notifications++);
          locks.checkGate?.complete();
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          expect(locks.checked, 1);
          expect(p.connectionInterrupted, isFalse);
          expect(notifications, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'renewal recovers from server errors silently and never overlaps',
    (tester) async {
      final locks = ScriptedLocks()
        ..renewals.addAll([serverError, serverError]);
      final p = Orders(Catalog(), locks)
        ..initializeDocumentSession(id: 'document');
      await tester.pumpWidget(ProviderLifetime(provider: p));
      await p.beginEditing();
      p.points = [point];
      var notifications = 0;
      p.addListener(() => notifications++);
      final renewal = p.renewDocumentLock();
      p.renewDocumentLock();
      await tester.pump();
      expect(locks.renewed, 1);
      await tester.pump(const Duration(milliseconds: 400));
      p.renewDocumentLock();
      await tester.pump(const Duration(milliseconds: 800));
      await renewal;
      expect(locks.renewed, 3);
      expect(notifications, 0);
      expect(p.canSave, isTrue);
    },
  );

  for (final error in [
    serverError,
    const ApiException(statusCode: 423, message: 'locked', ownerName: 'other'),
  ]) {
    testWidgets('unconfirmed renewal pauses safely: $error', (tester) async {
      final locks = ScriptedLocks()..renewals.addAll(List.filled(3, error));
      final p = Orders(Catalog(), locks)
        ..initializeDocumentSession(id: 'document');
      await tester.pumpWidget(ProviderLifetime(provider: p));
      await p.beginEditing();
      final renewal = p.renewDocumentLock();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));
      await renewal;
      expect(locks.renewed, error == serverError ? 3 : 1);
      expect(p.connectionInterrupted, isTrue);
      expect(p.canEdit, isFalse);
    });
  }
}

class ProviderLifetime extends StatefulWidget {
  final Orders provider;
  final Widget child;
  const ProviderLifetime({
    super.key,
    required this.provider,
    this.child = const SizedBox(),
  });
  @override
  State<ProviderLifetime> createState() => _ProviderLifetimeState();
}

class _ProviderLifetimeState extends State<ProviderLifetime> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    widget.provider.dispose();
    super.dispose();
  }
}
