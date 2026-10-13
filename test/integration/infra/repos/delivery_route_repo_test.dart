import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_document_api.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_api_data_source.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_repo.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_api_data_source.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_repo.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';

import '../../../auth/auth_fakes.dart';

class DocumentTransport extends RecordingTransport {
  Future<HttpTransportResponse> record(
    String method,
    String path,
    Map<String, String>? headers,
    Object? body,
  ) {
    final request = RecordedRequest(method, path, headers, body);
    requests.add(request);
    return respond(request);
  }

  @override
  Future<HttpTransportResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => record('PATCH', path, headers, body);
  @override
  Future<HttpTransportResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) => record('DELETE', path, headers, null);
}

void main() {
  for (final delivery in [true, false]) {
    group(delivery ? 'Delivery API' : 'Pickup API', () {
      final path = delivery
          ? '/protected/delivery-route-sheets'
          : '/protected/pickup-sheets';
      final key = delivery ? 'deliveryRouteSheets' : 'pickupSheets';
      const id = '019a1111-1111-7111-8111-111111111111';
      final json = <String, dynamic>{
        'deliveryDocumentId': id,
        'plannedDate': '2025-03-15',
        'createdAt': '2026-10-13T10:30:00',
        'isActive': true,
        if (delivery) ...{
          'driverId': id,
          'driverName': 'Водитель',
          'carId': id,
          'carModelAndNumber': 'Авто',
          'startMileage': 100.0,
          'endMileage': null,
        },
        'points': [
          {
            'pointId': id,
            'clientId': id,
            'clientName': 'Клиент',
            'address': 'Адрес',
            'phone': '123',
            'position': 0,
            'defaultPaymentMethodId': null,
            'defaultPaymentMethodName': null,
            'salesRepresentativeId': null,
            'salesRepresentativeName': null,
            'items': [
              {
                'productId': id,
                'productName': 'Вода',
                'quantity': 3,
                'price': 1.005,
              },
            ],
          },
        ],
      };
      late DocumentTransport transport;
      late AuthServiceImpl auth;
      late DeliveryDocumentDataSource source;
      late Future<RouteDocument> Function(Map<String, dynamic>) save;
      setUp(() async {
        transport = DocumentTransport();
        auth = AuthServiceImpl(
          repository: FakeAuthRepository(),
          tokenStorage: MemoryTokenStorage(),
        );
        await auth.login(username: 'manager', password: '');
        final client = ApiClient(
          transport: transport,
          authService: auth,
          userAgent: 'test',
        );
        if (delivery) {
          final api = ApiDeliveryRouteDataSource(client);
          final repo = DeliveryRouteRepositoryImpl(api);
          source = api;
          save = (data) =>
              repo.saveRouteSheet(DeliveryRouteSheet.fromJson(data));
        } else {
          final api = ApiPickupDataSource(client);
          final repo = PickupRepositoryImpl(api);
          source = api;
          save = (data) => repo.savePickupSheet(PickupSheet.fromJson(data));
        }
      });
      tearDown(() {
        transport.close();
        auth.dispose();
      });
      test(
        'pagination uses contract envelope, total and include_cancelled',
        () async {
          transport.respond = (request) async => HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': {
                key: request.path.contains('offset=0')
                    ? [json]
                    : [
                        {...json, 'deliveryDocumentId': 'second'},
                      ],
              },
              'total': 2,
              'offset': request.path.contains('offset=0') ? 0 : 1,
              'limit': 100,
            }),
          );
          final rows = await source.getAll(includeCancelled: true);
          expect(rows.length, 2);
          expect(transport.requests.map((r) => r.path), [
            '$path?include_cancelled=true&offset=0&limit=100',
            '$path?include_cancelled=true&offset=1&limit=100',
          ]);
          expect(
            transport.requests.first.headers!['Authorization'],
            'Bearer original-access',
          );
        },
      );
      test(
        'create and patch send only write fields and keep point identity',
        () async {
          transport.respond = (_) async => envelope(json);
          final created = await save({...json, 'deliveryDocumentId': null});
          expect(created.id, id);
          expect(created.date, DateTime(2025, 3, 15));
          expect(created.createdAt, DateTime(2026, 10, 13, 10, 30));
          final request = transport.requests.single.body as Map;
          expect(request['plannedDate'], '2025-03-15');
          expect(request.containsKey('createdAt'), isFalse);
          expect(request.containsKey('isActive'), isFalse);
          expect((request['points'] as List).single, {
            'clientId': id,
            'items': [
              {
                'productId': id,
                'productName': 'Вода',
                'quantity': 3,
                'price': 1.005,
              },
            ],
          });
          if (!delivery) {
            expect(request.keys.toSet(), {'plannedDate', 'points'});
          }
          await save(json);
          final patch = transport.requests.last;
          expect(patch.method, 'PATCH');
          expect(patch.path, '$path/$id');
          expect(((patch.body as Map)['points'] as List).single['pointId'], id);
          if (delivery) expect((patch.body as Map)['endMileage'], isNull);
        },
      );
      test('empty documents remain writable', () async {
        transport.respond = (_) async => envelope({...json, 'points': []});
        await save({...json, 'deliveryDocumentId': null, 'points': []});
        expect((transport.requests.single.body as Map)['points'], isEmpty);
      });
      test('cancel and restore are POST; release is bodyless DELETE', () async {
        transport.respond = (_) async => envelope({...json, 'isActive': false});
        await source.setActive(id, false);
        expect(transport.requests.last.path, '$path/$id/cancel');
        expect(transport.requests.last.method, 'POST');
        expect(transport.requests.last.body, isNull);
        await source.setActive(id, true);
        expect(transport.requests.last.path, '$path/$id/restore');
        transport.respond = (_) async => envelope({'ownerName': 'manager'});
        expect(await source.acquireEditLock(id), 'manager');
        expect(await source.renewEditLock(id), 'manager');
        expect(transport.requests.last.method, 'PATCH');
        transport.respond = (_) async => envelope(null);
        await source.releaseEditLock(id);
        expect(transport.requests.last.method, 'DELETE');
        expect(transport.requests.last.path, '$path/$id/edit-lock');
        expect(transport.requests.last.body, isNull);
      });
      test('423 preserves structured ownerName, never parses detail', () async {
        transport.respond = (_) async => const HttpTransportResponse(
          statusCode: 423,
          body: '{"detail":"Unrelated generic text","ownerName":"other-login"}',
        );
        await expectLater(
          source.acquireEditLock(id),
          throwsA(
            isA<ApiException>().having(
              (e) => e.ownerName,
              'ownerName',
              'other-login',
            ),
          ),
        );
      });
      test('DELETE retries after access token refresh', () async {
        var attempts = 0;
        transport.respond = (_) async => ++attempts == 1
            ? const HttpTransportResponse(
                statusCode: 401,
                body: '{"detail":"Expired"}',
              )
            : envelope(null);
        await source.releaseEditLock(id);
        expect(transport.requests.length, 2);
        expect(
          transport.requests.last.headers!['Authorization'],
          'Bearer renewed-access',
        );
      });
    });
  }
}
