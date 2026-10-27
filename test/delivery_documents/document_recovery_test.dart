import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';

import 'document_provider_test.dart' show Orders, Catalog, Locks, point;

void main() {
  late Orders provider;
  late Locks locks;
  setUp(() {
    locks = Locks();
    provider = Orders(Catalog(), locks)..points = [point];
  });
  tearDown(() => provider.dispose());

  PickupSheet snapshot({
    int revision = 1,
    int quantity = 2,
    String? operation,
  }) => PickupSheet(
    id: 'document',
    revision: revision,
    lastOperationId: operation,
    date: DateTime(2026, 10, 27),
    points: [
      point.copyWith(
        items: [
          DeliveryTaskItem(
            productId: point.items.single.productId,
            productName: point.items.single.productName,
            quantity: quantity,
            price: point.items.single.price,
          ),
        ],
      ),
    ],
  );

  Future<void> edit() async {
    provider.initializeDocumentSession(id: 'document');
    expect(await provider.beginEditing(), isTrue);
    provider.updateTaskQuantity(0, 0, 3);
    provider.recoveryDocument = snapshot();
  }

  test(
    'short outage preserves mode, draft and revision without saving',
    () async {
      await edit();
      provider.handleDocumentError(const SocketException('offline'));
      expect(provider.isEditing, isTrue);
      expect(provider.canEdit, isFalse);
      expect(provider.points.single.items.single.quantity, 3);
      locks.connectionError = const SocketException('offline');
      expect(await provider.retryConnection(), isFalse);
      expect(provider.connectionInterrupted, isTrue);
      locks.connectionError = null;
      expect(await provider.retryConnection(), isTrue);
      expect(provider.canSave, isTrue);
      expect(provider.points.single.items.single.quantity, 3);
      expect(provider.documentRevision, 1);
      expect(locks.acquired, 2);
    },
  );

  test('expired own lock is reacquired without losing draft', () async {
    await edit();
    locks.failRenew = true;
    await provider.renewDocumentLock();
    expect(provider.connectionInterrupted, isTrue);
    locks.failRenew = false;
    expect(await provider.retryConnection(), isTrue);
    expect(provider.points.single.items.single.quantity, 3);
    expect(provider.canSave, isTrue);
  });

  test(
    'another owner forces fresh view and never releases their lock',
    () async {
      await edit();
      provider.handleDocumentError(const SocketException('offline'));
      locks.acquireError = const ApiException(
        statusCode: 423,
        message: 'locked',
        ownerName: 'other',
      );
      expect(await provider.retryConnection(), isTrue);
      expect(provider.isEditing, isFalse);
      expect(provider.points.single.items.single.quantity, 2);
      expect(provider.documentError, contains('other'));
      expect(locks.released, 0);
    },
  );

  test('free lock with a newer revision discards stale edits and releases own lock', () async {
    await edit();
    provider.handleDocumentError(const SocketException('offline'));
    provider.recoveryDocument = snapshot(revision: 2, quantity: 4);
    expect(await provider.retryConnection(), isTrue);
    expect(provider.isEditing, isFalse);
    expect(provider.documentRevision, 2);
    expect(provider.points.single.items.single.quantity, 4);
    expect(provider.documentError, contains('Документ изменился'));
    expect(locks.released, 1);
  });

  test(
    'lost save response is recognized by operation id without another save',
    () async {
      await edit();
      provider.prepareDocumentSave();
      final operation = provider.saveOperationId;
      provider.handleDocumentError(const SocketException('response lost'));
      provider.recoveryDocument = snapshot(
        revision: 2,
        quantity: 3,
        operation: operation,
      );
      expect(await provider.retryConnection(), isTrue);
      expect(provider.isEditing, isFalse);
      expect(provider.documentChanged, isTrue);
      expect(provider.points.single.items.single.quantity, 3);
      expect(provider.documentError, contains('подтвердил сохранение'));
    },
  );

  test(
    'failed fresh read keeps dialog up instead of showing draft as saved',
    () async {
      await edit();
      provider.handleDocumentError(const SocketException('offline'));
      locks.acquireError = const ApiException(
        statusCode: 423,
        message: 'locked',
        ownerName: 'other',
      );
      provider.recoveryDocument = null;
      provider.failRead = true;
      expect(await provider.retryConnection(), isFalse);
      expect(provider.connectionInterrupted, isTrue);
      expect(provider.isEditing, isTrue);
      expect(provider.canSave, isFalse);
    },
  );

  test(
    'new document is reconciled after a lost creation response without locking',
    () async {
      provider.initializeDocumentSession();
      provider.points = [point];
      provider.prepareDocumentSave();
      final operation = provider.saveOperationId;
      provider.handleDocumentError(const SocketException('response lost'));
      provider.recoveryDocument = snapshot(operation: operation);
      expect(await provider.retryConnection(), isTrue);
      expect(provider.documentId, 'document');
      expect(provider.isEditing, isFalse);
      expect(provider.documentChanged, isTrue);
      expect(locks.acquired, 0);
    },
  );

  test(
    'unsaved new form retains input and creation key after reconnect',
    () async {
      provider.initializeDocumentSession();
      provider.points = [point];
      provider.prepareDocumentSave();
      final operation = provider.saveOperationId;
      provider.handleDocumentError(const SocketException('offline'));
      expect(await provider.retryConnection(), isTrue);
      expect(provider.documentId, isNull);
      expect(provider.canSave, isTrue);
      expect(provider.points, [point]);
      expect(provider.saveOperationId, operation);
      expect(locks.acquired, 0);
    },
  );
}
