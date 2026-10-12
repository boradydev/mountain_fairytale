import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_api_data_source.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_repo.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';

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
  final paymentMethod = {
    'paymentMethodId': '019a1111-1111-7111-8111-111111111111',
    'name': 'Иванов Иван',
    'createdAt': '2026-10-11T10:00:00',
    'isActive': true,
  };
  late PatchTransport transport;
  late AuthServiceImpl auth;
  late PaymentMethodRepositoryImpl repo;
  setUp(() async {
    transport = PatchTransport();
    auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    repo = PaymentMethodRepositoryImpl(
      ApiPaymentMethodDataSource(
        ApiClient(transport: transport, authService: auth, userAgent: 'test'),
      ),
    );
  });
  tearDown(() {
    transport.close();
    auth.dispose();
  });

  test(
    'list uses snake case query, Bearer auth and data.paymentMethods envelope',
    () async {
      transport.respond = (_) async => envelope({
        'paymentMethods': [paymentMethod],
      });
      final result = await repo.getAllPaymentMethods(includeDeactivated: true);
      expect(result.single.id, paymentMethod['paymentMethodId']);
      expect(result.single.createdAt, DateTime(2026, 10, 11, 10));
      expect(
        transport.requests.single.path,
        '/protected/payment-methods?include_deactivated=true',
      );
      expect(
        transport.requests.single.headers!['Authorization'],
        'Bearer original-access',
      );
      await repo.getAllPaymentMethods();
      expect(
        transport.requests.last.path,
        '/protected/payment-methods?include_deactivated=false',
      );
    },
  );

  test(
    'create and rename unwrap server identity and send only requested fields',
    () async {
      transport.respond = (_) async => envelope(paymentMethod);
      final created = await repo.createPaymentMethod(
        const CreatePaymentMethodRequest(name: 'Иванов Иван'),
      );
      expect(created.id, paymentMethod['paymentMethodId']);
      expect(
        transport.requests.single.path,
        '/protected/payment-methods/create',
      );
      expect(transport.requests.single.method, 'POST');
      expect(transport.requests.single.body, {'name': 'Иванов Иван'});
      await repo.updatePaymentMethod(
        created.id,
        const UpdatePaymentMethodRequest(name: 'Иванов'),
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
          : envelope({...paymentMethod, 'isActive': false});
      await repo.updatePaymentMethod(
        paymentMethod['paymentMethodId'] as String,
        const UpdatePaymentMethodRequest(isActive: false),
      );
      expect(transport.requests, hasLength(2));
      expect(transport.requests.every((r) => r.method == 'PATCH'), isTrue);
      expect(transport.requests.last.body, {'isActive': false});
      expect(
        transport.requests.last.headers!['Authorization'],
        'Bearer renewed-access',
      );
      transport.respond = (_) async => envelope(paymentMethod);
      final active = await repo.updatePaymentMethod(
        paymentMethod['paymentMethodId'] as String,
        const UpdatePaymentMethodRequest(isActive: true),
      );
      expect(active.isActive, isTrue);
      expect(transport.requests.last.body, {'isActive': true});
    },
  );

  test(
    'duplicate lookup encodes name and preserves inactive status and null',
    () async {
      transport.respond = (_) async =>
          envelope({...paymentMethod, 'isActive': false});
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
  test('fetch by UUID preserves naive timestamp and conflict status', () async {
    transport.respond = (_) async => envelope(paymentMethod);
    final result = await repo.getPaymentMethodById(
      paymentMethod['paymentMethodId'] as String,
    );
    expect(
      transport.requests.single.path,
      '/protected/payment-methods/${result.id}',
    );
    expect(result.createdAt.isUtc, isFalse);
    expect(result.toJson()['createdAt'], '2026-10-11T10:00:00.000');
    transport.respond = (_) async => const HttpTransportResponse(
      statusCode: 409,
      body: '{"detail":"Payment method name already exists"}',
    );
    await expectLater(
      repo.createPaymentMethod(const CreatePaymentMethodRequest(name: 'Same')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
  });
}
