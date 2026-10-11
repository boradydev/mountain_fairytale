import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/drivers/data/drivers_api_data_source.dart';
import 'package:mountain_fairytale/features/drivers/data/drivers_repo.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';

import '../auth/auth_fakes.dart';

class PatchTransport extends RecordingTransport {
  @override
  Future<HttpTransportResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final request = RecordedRequest('PATCH', path, headers, body);
    requests.add(request);
    return respond(request);
  }
}

void main() {
  final driver = {
    'driverId': '019a1111-1111-7111-8111-111111111111',
    'name': 'Иванов Иван',
    'createdAt': '2026-10-11T10:00:00',
    'isActive': true,
  };
  late PatchTransport transport;
  late AuthServiceImpl auth;
  late DriverRepositoryImpl repo;
  setUp(() async {
    transport = PatchTransport();
    auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    repo = DriverRepositoryImpl(
      ApiDriverDataSource(
        ApiClient(transport: transport, authService: auth, userAgent: 'test'),
      ),
    );
  });
  tearDown(() {
    transport.close();
    auth.dispose();
  });

  test(
    'list uses snake case query, Bearer auth and data.drivers envelope',
    () async {
      transport.respond = (_) async => envelope({
        'drivers': [driver],
      });
      final result = await repo.getAvailableDrivers(includeDeactivated: true);
      expect(result.single.id, driver['driverId']);
      expect(result.single.createdAt, DateTime(2026, 10, 11, 10));
      expect(
        transport.requests.single.path,
        '/protected/drivers?include_deactivated=true',
      );
      expect(
        transport.requests.single.headers!['Authorization'],
        'Bearer original-access',
      );
      await repo.getAvailableDrivers();
      expect(
        transport.requests.last.path,
        '/protected/drivers?include_deactivated=false',
      );
    },
  );

  test(
    'create and rename unwrap server identity and send only requested fields',
    () async {
      transport.respond = (_) async => envelope(driver);
      final created = await repo.createDriver(
        const CreateDriverRequest(name: 'Иванов Иван'),
      );
      expect(created.id, driver['driverId']);
      expect(transport.requests.single.path, '/protected/drivers/create');
      expect(transport.requests.single.method, 'POST');
      expect(transport.requests.single.body, {'name': 'Иванов Иван'});
      await repo.updateDriver(
        created.id,
        const UpdateDriverRequest(name: 'Иванов'),
      );
      expect(transport.requests.last.method, 'PATCH');
      expect(transport.requests.last.body, {'name': 'Иванов'});
    },
  );

  test(
    'deactivation and activation use PATCH; expired access retries PATCH',
    () async {
      var attempts = 0;
      transport.respond = (_) async => ++attempts == 1
          ? const HttpTransportResponse(
              statusCode: 401,
              body: '{"detail":"Expired"}',
            )
          : envelope({...driver, 'isActive': false});
      await repo.deactivateDriver(driver['driverId'] as String);
      expect(transport.requests, hasLength(2));
      expect(transport.requests.every((r) => r.method == 'PATCH'), isTrue);
      expect(transport.requests.last.body, {'isActive': false});
      expect(
        transport.requests.last.headers!['Authorization'],
        'Bearer renewed-access',
      );
      transport.respond = (_) async => envelope(driver);
      final active = await repo.updateDriver(
        driver['driverId'] as String,
        const UpdateDriverRequest(isActive: true),
      );
      expect(active.isActive, isTrue);
      expect(transport.requests.last.body, {'isActive': true});
    },
  );

  test(
    'duplicate lookup encodes name and preserves inactive status and null',
    () async {
      transport.respond = (_) async => envelope({...driver, 'isActive': false});
      final match = await repo.checkDuplicate('Иванов & Иван');
      expect(match!.isActive, isFalse);
      expect(
        Uri.parse(transport.requests.single.path).queryParameters['name'],
        'Иванов & Иван',
      );
      transport.respond = (_) async => envelope(null);
      expect(await repo.checkDuplicate('Другой'), isNull);
    },
  );

  test('API failure is not mistaken for no duplicate', () async {
    transport.respond = (_) async => const HttpTransportResponse(
      statusCode: 422,
      body: '{"detail":"Invalid name"}',
    );
    await expectLater(
      repo.checkDuplicate('Иван'),
      throwsA(isA<ApiException>()),
    );
  });
  test(
    'route serialization retains UUID and accepts legacy sheets without it',
    () {
      final sheet = DeliveryRouteSheet(
        date: DateTime(2026),
        driverName: 'Иванов',
        driverId: driver['driverId'] as String,
        carId: 1,
        carModelAndNumber: 'Авто',
        startMileage: 0,
        points: [],
      );
      expect(
        DeliveryRouteSheet.fromJson(sheet.toJson()).driverId,
        driver['driverId'],
      );
      final legacy = sheet.toJson()..remove('driverId');
      expect(DeliveryRouteSheet.fromJson(legacy).driverId, isNull);
    },
  );
}
