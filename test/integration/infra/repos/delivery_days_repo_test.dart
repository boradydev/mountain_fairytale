import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_api_data_source.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_repo.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';

import '../../../auth/auth_fakes.dart';

void main() {
  late RecordingTransport transport;
  late ApiDeliveryRepository repository;
  setUp(() async {
    transport = RecordingTransport();
    final auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    repository = ApiDeliveryRepository(
      ApiDeliveryDaysDataSource(
        ApiClient(transport: transport, authService: auth, userAgent: 'test'),
      ),
    );
  });
  test(
    'days parse server dates, UUIDs, historical names, counts and total',
    () async {
      transport.respond = (_) async => HttpTransportResponse(
        statusCode: 200,
        body: jsonEncode({
          'total': 20,
          'data': {
            'deliveryDays': [
              {
                'plannedDate': '2026-10-18',
                'deliveryPointsCount': 3,
                'pickupPointsCount': 2,
                'products': [
                  {
                    'productId': '019a1111-1111-7111-8111-111111111111',
                    'productName': 'Вода Горная / Вода Родниковая',
                    'quantity': 9,
                  },
                ],
                'totalAmount': 6.71,
              },
            ],
          },
        }),
      );
      final page = await repository.getDeliveryDays(offset: 7, limit: 7);
      expect(page.total, 20);
      final day = page.days.single;
      expect(day.plannedDate, DateTime(2026, 10, 18));
      expect(day.plannedDate.isUtc, isFalse);
      expect(day.deliveryPointsCount, 3);
      expect(day.pickupPointsCount, 2);
      expect(day.products.single.productName, 'Вода Горная / Вода Родниковая');
      expect(
        day.products.single.productId,
        '019a1111-1111-7111-8111-111111111111',
      );
      expect(day.totalAmount, 6.71);
      expect(
        transport.requests.single.path,
        '/protected/delivery-days?offset=7&limit=7',
      );
      expect(transport.requests.single.method, 'GET');
      expect(
        transport.requests.single.headers!['Authorization'],
        'Bearer original-access',
      );
    },
  );
  test(
    'empty pages retain total and do not generate dates on client',
    () async {
      transport.respond = (_) async => HttpTransportResponse(
        statusCode: 200,
        body: jsonEncode({
          'total': 3,
          'data': {'deliveryDays': []},
        }),
      );
      final page = await repository.getDeliveryDays(offset: 10, limit: 7);
      expect(page.days, isEmpty);
      expect(page.total, 3);
    },
  );
  test(
    'date documents are a single unpaginated GET with flat documentType',
    () async {
      transport.respond = (_) async => envelope({
        'documents': [
          {
            'documentType': 'pickupSheet',
            'deliveryDocumentId': 'pickup',
            'plannedDate': '2026-10-18',
            'isActive': true,
            'createdAt': '2026-10-13T12:00:00',
            'points': [],
          },
          {
            'documentType': 'deliveryRouteSheet',
            'deliveryDocumentId': 'delivery',
            'plannedDate': '2026-10-18',
            'isActive': false,
            'driverId': 'driver',
            'driverName': 'Водитель',
            'carId': 'car',
            'carModelAndNumber': 'Авто',
            'startMileage': 1.0,
            'endMileage': null,
            'points': [],
          },
        ],
      });
      final documents = await repository.getDayDocuments(
        DateTime(2026, 10, 18),
        includeCancelled: true,
      );
      expect(documents.first, isA<PickupSheet>());
      expect(documents.last, isA<DeliveryRouteSheet>());
      expect(documents.last.isActive, isFalse);
      expect(
        transport.requests.single.path,
        '/protected/delivery-days/2026-10-18/documents?include_cancelled=true',
      );
      expect(transport.requests.single.method, 'GET');
      await repository.getDayDocuments(DateTime(2026, 10, 18));
      expect(transport.requests.last.path, endsWith('include_cancelled=false'));
    },
  );
  test('unknown document type is not silently treated as pickup', () async {
    transport.respond = (_) async => envelope({
      'documents': [
        {'documentType': 'unknown'},
      ],
    });
    await expectLater(
      repository.getDayDocuments(DateTime(2026)),
      throwsFormatException,
    );
  });
  test(
    'errors propagate for retry instead of becoming empty calendar',
    () async {
      transport.respond = (_) async => const HttpTransportResponse(
        statusCode: 500,
        body: '{"detail":"Failed"}',
      );
      await expectLater(
        repository.getDeliveryDays(offset: 0, limit: 7),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
