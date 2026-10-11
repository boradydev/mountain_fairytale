import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/cars/data/cars_api_data_source.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_repo.dart';

import '../auth/auth_fakes.dart';

class CarPatchTransport extends RecordingTransport {
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
  const carId = '019a1111-1111-7111-8111-111111111111';
  final car = {
    'carId': carId,
    'model': 'Газель Бизнес',
    'number': 'А123КХ126',
    'currentMileage': 12500.0,
    'isActive': true,
  };
  late CarPatchTransport transport;
  late AuthServiceImpl auth;
  late CarRepositoryImpl repo;

  setUp(() async {
    transport = CarPatchTransport();
    auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    repo = CarRepositoryImpl(
      ApiCarDataSource(
        ApiClient(transport: transport, authService: auth, userAgent: 'test'),
      ),
    );
  });

  tearDown(() {
    transport.close();
    auth.dispose();
  });

  test(
    'list requests inactive cars and decodes UUID response envelope',
    () async {
      transport.respond = (_) async => envelope({
        'cars': [car],
      });

      final result = await repo.getAvailableCars(includeDeactivated: true);

      expect(result.single.id, carId);
      expect(result.single.isActive, isTrue);
      expect(
        transport.requests.single.path,
        '/protected/cars?include_deactivated=true',
      );
      expect(
        transport.requests.single.headers!['Authorization'],
        'Bearer original-access',
      );
    },
  );

  test('create canonicalizes number and patch deactivates by UUID', () async {
    transport.respond = (_) async => envelope(car);

    final created = await repo.createCar(
      const CreateCarRequest(
        model: 'Газель Бизнес',
        number: 'a123kx 126',
      ),
    );
    expect(created.id, carId);
    expect(transport.requests.single.method, 'POST');
    expect(transport.requests.single.path, '/protected/cars/create');
    expect(
      transport.requests.single.body,
      {'model': 'Газель Бизнес', 'number': 'А123КХ126', 'currentMileage': 0},
    );

    transport.respond = (_) async => envelope({...car, 'isActive': false});
    final deactivated = await repo.deactivateCar(carId);
    expect(deactivated.isActive, isFalse);
    expect(transport.requests.last.method, 'PATCH');
    expect(transport.requests.last.path, '/protected/cars/$carId');
    expect(transport.requests.last.body, {'isActive': false});
  });

  test(
    'duplicate lookup normalizes number and decodes null response',
    () async {
      transport.respond = (_) async => envelope(car);

      final match = await repo.checkDuplicate('a123 kx 126');

      expect(match?.id, carId);
      expect(
        Uri.parse(transport.requests.single.path).queryParameters['number'],
        'А123КХ126',
      );

      transport.respond = (_) async => envelope(null);
      expect(await repo.checkDuplicate('В456РР26'), isNull);
    },
  );
}
