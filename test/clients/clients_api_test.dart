import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/clients/data/clients_api_data_source.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/data/clients_repo.dart';

import '../auth/auth_fakes.dart';

const clientId = '019a1111-1111-7111-8111-111111111111';
final clientJson = <String, dynamic>{
  'clientId': clientId,
  'name': 'Магазин',
  'phone': '+7 (912) 345-67-89',
  'address': 'Москва',
  'sleepingThresholdDays': 0,
  'lastDeliveryDate': null,
  'lastDeliveryQuantity': null,
  'cooldownUntil': null,
  'salesRepresentativeId': null,
  'salesRepresentativeName': null,
  'defaultPaymentMethodId': null,
  'defaultPaymentMethodName': null,
  'createdAt': '2026-10-12T10:00:00',
  'isActive': true,
};

class ClientTransport extends RecordingTransport {
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
  late ClientTransport transport;
  late AuthServiceImpl auth;
  late ClientRepositoryImpl repo;
  setUp(() async {
    transport = ClientTransport();
    auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    repo = ClientRepositoryImpl(
      ApiClientDataSource(
        ApiClient(transport: transport, authService: auth, userAgent: 'test'),
      ),
    );
  });
  tearDown(() {
    transport.close();
    auth.dispose();
  });

  test('server search, pagination, auth and UUID response envelope', () async {
    transport.respond = (request) async {
      final offset = int.parse(
        Uri.parse(request.path).queryParameters['offset']!,
      );
      return HttpTransportResponse(
        statusCode: 200,
        body: jsonEncode({
          'offset': offset,
          'limit': 100,
          'total': 101,
          'data': {
            'clients': List.generate(
              offset == 0 ? 100 : 1,
              (index) => {
                ...clientJson,
                'clientId': '$clientId-${offset + index}',
              },
            ),
          },
        }),
      );
    };
    final result = await repo.getAllClients(
      search: 'Иван & +7',
      includeDeactivated: true,
    );
    expect(result, hasLength(101));
    expect(result.last.id, '$clientId-100');
    expect(result.first.createdAt, DateTime(2026, 10, 12, 10));
    expect(result.first.isActive, isTrue);
    expect(transport.requests, hasLength(2));
    final query = Uri.parse(transport.requests.last.path).queryParameters;
    expect(query, {
      'include_deactivated': 'true',
      'offset': '100',
      'limit': '100',
      'search': 'Иван & +7',
    });
    expect(
      transport.requests.first.headers!['Authorization'],
      'Bearer original-access',
    );
  });

  test('create sends writable fields; GET uses server UUID', () async {
    transport.respond = (_) async => envelope(clientJson);
    final created = await repo.createClient(
      const CreateClientRequest(
        name: 'Магазин',
        phone: '123',
        address: 'Москва',
        sleepingThresholdDays: 0,
      ),
    );
    expect(created.id, clientId);
    expect(transport.requests.single.method, 'POST');
    expect(transport.requests.single.path, '/protected/clients/create');
    expect(transport.requests.single.body, {
      'name': 'Магазин',
      'phone': '123',
      'address': 'Москва',
      'sleepingThresholdDays': 0,
      'cooldownUntil': null,
      'salesRepresentativeId': null,
      'defaultPaymentMethodId': null,
    });
    await repo.getClientById(created.id);
    expect(transport.requests.last.path, '/protected/clients/$clientId');
  });

  test(
    'partial PATCH omits unrelated fields and supports explicit null',
    () async {
      transport.respond = (_) async => envelope(clientJson);
      await repo.updateClient(
        clientId,
        const UpdateClientRequest(defaultPaymentMethodId: 'payment-uuid'),
      );
      expect(transport.requests.last.body, {
        'defaultPaymentMethodId': 'payment-uuid',
      });
      await repo.updateClient(
        clientId,
        const UpdateClientRequest(
          salesRepresentativeId: null,
          defaultPaymentMethodId: null,
          cooldownUntil: null,
        ),
      );
      expect(transport.requests.last.body, {
        'salesRepresentativeId': null,
        'defaultPaymentMethodId': null,
        'cooldownUntil': null,
      });
      await repo.updateCooldown(clientId, DateTime(2026, 10, 12, 15, 30));
      expect(transport.requests.last.body, {
        'cooldownUntil': '2026-10-12T15:30:00.000',
      });
    },
  );

  test('deactivation uses PATCH and expired authorization refreshes', () async {
    var attempts = 0;
    transport.respond = (_) async => ++attempts == 1
        ? const HttpTransportResponse(
            statusCode: 401,
            body: '{"detail":"Expired"}',
          )
        : envelope({...clientJson, 'isActive': false});
    await repo.deleteClient(clientId);
    expect(transport.requests, hasLength(2));
    expect(
      transport.requests.every((request) => request.method == 'PATCH'),
      isTrue,
    );
    expect(transport.requests.last.body, {'isActive': false});
    expect(
      transport.requests.last.headers!['Authorization'],
      'Bearer renewed-access',
    );
  });

  test('duplicate requires all three encoded values, preserves inactive match and null', () async {
    transport.respond = (_) async =>
        envelope({...clientJson, 'isActive': false});
    final duplicate = await repo.checkDuplicate(
      'Имя & Co',
      '+7 123',
      'Адрес #1',
    );
    expect(duplicate!.isActive, isFalse);
    expect(Uri.parse(transport.requests.last.path).queryParameters, {
      'name': 'Имя & Co',
      'phone': '+7 123',
      'address': 'Адрес #1',
    });
    transport.respond = (_) async => envelope(null);
    expect(await repo.checkDuplicate('Имя', '123', 'Адрес'), isNull);
  });

  test('active directory values use real API identifiers', () async {
    transport.respond = (request) async =>
        request.path.contains('sales-representatives')
        ? envelope({
            'salesRepresentatives': [
              {'salesRepresentativeId': 'rep-uuid', 'name': 'Представитель'},
            ],
          })
        : envelope({
            'paymentMethods': [
              {'paymentMethodId': 'method-uuid', 'name': 'Наличные'},
            ],
          });
    expect((await repo.getSalesRepresentatives()).single.id, 'rep-uuid');
    expect((await repo.getPaymentMethods()).single.id, 'method-uuid');
    expect(
      transport.requests.every(
        (request) =>
            Uri.parse(request.path).queryParameters['include_deactivated'] ==
            'false',
      ),
      isTrue,
    );
  });

  test('HTTP conflict propagates by status code', () async {
    transport.respond = (_) async => const HttpTransportResponse(
      statusCode: 409,
      body: '{"detail":"Client phone already exists"}',
    );
    await expectLater(
      repo.updateClient(clientId, const UpdateClientRequest(phone: '123')),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 409),
      ),
    );
  });
}
