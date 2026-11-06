import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_repo.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_repo.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';

import 'constructors_test.dart' show Cars, Drivers, PrintService;
import 'document_provider_test.dart' show Catalog, Clients, Payments, point;

// Exercises both real repositories: create/patch must never be retried.
class UncertainWrites implements PickupDataSource, DeliveryRouteDataSource {
  Map<String, dynamic> state;
  final bool committed;
  final Object writeError;
  Object? readError;
  Object? healthError;
  Map<String, dynamic>? request;
  int creates = 0, patches = 0, acquisitions = 0;
  UncertainWrites(this.state, this.committed, this.writeError);

  Future<Map<String, dynamic>> write(Map<String, dynamic> json) async {
    request = json;
    if (committed) {
      state = {
        ...state,
        'revision': patches > 0 ? 2 : 1,
        'lastOperationId': json['operationId'] ?? json['creationRequestId'],
        'points': [
          point
              .copyWith(items: [point.items.single.copyWith(quantity: 3)])
              .toJson(),
        ],
      };
    }
    throw writeError;
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> json) {
    creates++;
    return write(json);
  }

  @override
  Future<Map<String, dynamic>> patch(String id, Map<String, dynamic> json) {
    patches++;
    return write(json);
  }

  @override
  Future<void> checkConnection() async {
    if (healthError != null) throw healthError!;
  }

  @override
  Future<String> acquireEditLock(String id) async {
    acquisitions++;
    return 'manager';
  }

  @override
  Future<String> renewEditLock(String id) async => 'manager';
  @override
  Future<void> releaseEditLock(String id) async {}
  @override
  Future<Map<String, dynamic>> getById(String id) async {
    if (readError != null) throw readError!;
    return state;
  }

  @override
  Future<Map<String, dynamic>> findCreated(String requestId) async {
    if (readError != null) throw readError!;
    if (!committed) {
      throw const ApiException(statusCode: 404, message: 'not created');
    }
    return state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final pickup in [true, false]) {
    for (final creating in [true, false]) {
      for (final committed in [true, false]) {
        for (final error in [
          const ApiException(statusCode: 500, message: 'write failed'),
          const SocketException('response lost'),
        ]) {
          test(
            '${pickup ? 'pickup' : 'route'} ${creating ? 'POST' : 'PATCH'} committed=$committed $error reconciles without a second write',
            () async {
              final initial = pickup
                  ? PickupSheet(
                      id: 'document',
                      date: DateTime(2026, 11, 6),
                      points: [point],
                    ).toJson()
                  : DeliveryRouteSheet(
                      id: 'document',
                      date: DateTime(2026, 11, 6),
                      driverName: 'driver',
                      driverId: 'driver',
                      carId: 'car',
                      carModelAndNumber: 'car',
                      startMileage: 100,
                      points: [point],
                    ).toJson();
              final source = UncertainWrites(initial, committed, error);
              final OrderPointsProvider p;
              final Future<bool> Function() save;
              if (pickup) {
                final provider = PickupConstructorProvider(
                  pickupRepo: PickupRepositoryImpl(source),
                  productRepo: Catalog(),
                  paymentMethodRepo: Payments(),
                  clientRepo: Clients(),
                );
                p = provider;
                save = provider.savePickup;
              } else {
                final provider = RouteConstructorProvider(
                  routeRepo: DeliveryRouteRepositoryImpl(source),
                  carRepo: Cars(),
                  driverRepo: Drivers(),
                  printService: PrintService(),
                  productRepo: Catalog(),
                  paymentMethodRepo: Payments(),
                  clientRepo: Clients(),
                );
                provider.selectedCar = Car.fromJson({
                  ...Cars().car.toJson(),
                  'isActive': true,
                });
                provider.selectedDriver = Driver.fromJson({
                  ...Drivers().driver.toJson(),
                  'isActive': true,
                });
                p = provider;
                save = provider.saveRoute;
              }
              addTearDown(p.dispose);
              p.initializeDocumentSession(id: creating ? null : 'document');
              if (!creating) expect(await p.beginEditing(), isTrue);
              p.points = [point];
              p.updateTaskQuantity(0, 0, 3);
              final operation = p.saveOperationId;
              expect(await save(), isFalse);
              expect(source.creates, creating ? 1 : 0);
              expect(source.patches, creating ? 0 : 1);
              expect(p.connectionInterrupted, isTrue);
              expect(p.canSave, isFalse);
              expect(
                p.documentError,
                contains('Не удалось подтвердить сохранение'),
              );
              expect(
                source.request![creating ? 'creationRequestId' : 'operationId'],
                operation,
              );
              source.healthError = const ApiException(
                statusCode: 503,
                message: 'busy',
              );
              expect(await p.retryConnection(), isFalse);
              source.healthError = null;
              source.readError = const SocketException('read failed');
              expect(await p.retryConnection(), isFalse);
              expect(p.canSave, isFalse);
              expect(p.points.single.items.single.quantity, 3);
              expect(await save(), isFalse);
              source.readError = null;
              expect(await p.retryConnection(), isTrue);
              expect(source.creates + source.patches, 1);
              expect(p.points.single.items.single.quantity, 3);
              if (committed) {
                expect(p.isEditing, isFalse);
                expect(p.documentChanged, isTrue);
                expect(p.documentRevision, creating ? 1 : 2);
                expect(p.documentError, contains('подтвердил сохранение'));
              } else {
                expect(p.canSave, isTrue);
                expect(p.saveOperationId, operation);
              }
            },
          );
        }
      }
    }
  }
}
