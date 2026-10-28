import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/client_build_info.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_provider.dart';
import 'package:mountain_fairytale/features/auth/data/auth_api_data_source.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';

import '../auth/auth_fakes.dart';

void main() {
  late HttpServer server;
  late HttpTransport transport;
  late AppCompatibilityProvider compatibility;
  late Future<void> Function(HttpRequest) respond;
  late List<HttpRequest> requests;

  Future<void> json(
    HttpRequest request,
    Object body, {
    int status = 200,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    respond = (request) => json(request, {
      'data': {'backendVersion': '1.5.0', 'minClientVersion': '1.9.0'},
    });
    server.listen((request) async {
      requests.add(request);
      await respond(request);
    });
    transport = HttpTransport(baseUrl: 'http://127.0.0.1:${server.port}');
    compatibility = AppCompatibilityProvider(
      transport: transport,
      loadBuild: () async => ClientBuildInfo(version: '1.10.0', build: '42'),
    );
  });

  tearDown(() async {
    compatibility.dispose();
    transport.close();
    await server.close(force: true);
  });

  test(
    'numeric comparison, real metadata on all transport methods and auth',
    () async {
      await compatibility.check();
      expect(compatibility.compatible, isTrue);
      respond = (request) => json(request, {'data': originalTokens.toJson()});
      final auth = AuthApiDataSource(transport: transport);
      await auth.login(username: 'manager', password: '');
      await auth.refresh(refreshToken: 'refresh');
      await transport.get('/protected/data');
      await transport.patch('/protected/data');
      await transport.put('/protected/data');
      await transport.delete('/protected/data');
      await transport.getLongPolling('/protected/updates');
      for (final request in requests) {
        expect(request.headers.value('X-Client-Version'), '1.10.0');
        expect(request.headers.value('X-Client-Build'), '42');
        expect(
          request.headers.value('User-Agent'),
          'MountainFairytale/1.10.0+42 Windows',
        );
      }
    },
  );

  test('work cannot start before successful bootstrap', () async {
    await expectLater(
      transport.get('/protected/data'),
      throwsA(isA<ApiException>()),
    );
    expect(requests, isEmpty);
  });

  test(
    'old version is blocked at startup and after cancelled update',
    () async {
      respond = (request) => json(request, {
        'data': {'backendVersion': '2.0.0', 'minClientVersion': '2.0.0'},
      });
      await compatibility.check();
      expect(compatibility.status, CompatibilityStatus.updateRequired);
      await expectLater(
        transport.post('/public/auth/login'),
        throwsA(isA<ApiException>()),
      );
      expect(requests, hasLength(1));
      await compatibility.check();
      expect(compatibility.status, CompatibilityStatus.updateRequired);
    },
  );

  test(
    'hot API requirement blocks later requests without refresh or token loss',
    () async {
      await compatibility.check();
      final storage = MemoryTokenStorage();
      final repository = FakeAuthRepository();
      final auth = AuthServiceImpl(
        repository: repository,
        tokenStorage: storage,
      );
      addTearDown(auth.dispose);
      await auth.login(username: 'manager', password: '');
      final api = ApiClient(
        transport: transport,
        authService: auth,
        userAgent: 'test',
      );
      respond = (request) => json(request, {
        'code': 'CLIENT_UPDATE_REQUIRED',
        'minClientVersion': '2.0.0',
        'backendVersion': '2.0.0',
        'detail': 'update',
      }, status: 409);
      await expectLater(
        api.get('/protected/data'),
        throwsA(isA<ApiException>()),
      );
      expect(compatibility.status, CompatibilityStatus.updateRequired);
      expect(compatibility.workEpoch, 1);
      final count = requests.length;
      await expectLater(
        api.get('/protected/data'),
        throwsA(isA<ApiException>()),
      );
      expect(requests, hasLength(count));
      expect(repository.refreshCalls, 0);
      expect(storage.refresh, originalTokens.refreshToken);
      expect(auth.isAuthenticated, isTrue);
    },
  );

  test(
    'ordinary conflict and temporary API outage do not demand an update',
    () async {
      await compatibility.check();
      respond = (request) => json(request, {'detail': 'conflict'}, status: 409);
      await transport.post('/protected/data');
      expect(compatibility.compatible, isTrue);
      respond = (request) =>
          json(request, {'detail': 'unavailable'}, status: 503);
      await transport.get('/protected/data');
      expect(compatibility.compatible, isTrue);
      respond = (request) => json(request, {'data': {}});
      expect((await transport.get('/protected/data')).statusCode, 200);
    },
  );

  test(
    'bootstrap failures can recover without restarting the client',
    () async {
      respond = (request) =>
          json(request, {'detail': 'unavailable'}, status: 503);
      await compatibility.check();
      expect(compatibility.status, CompatibilityStatus.error);
      respond = (request) => json(request, {
        'data': {'backendVersion': '1.5.0', 'minClientVersion': '1.9.0'},
      });
      await compatibility.check();
      expect(compatibility.compatible, isTrue);
    },
  );

  test('failed retry never unlocks an outdated client', () async {
    respond = (request) => json(request, {
      'data': {'backendVersion': '2.0.0', 'minClientVersion': '2.0.0'},
    });
    await compatibility.check();
    respond = (request) => json(request, {}, status: 503);
    await compatibility.check();
    expect(compatibility.status, CompatibilityStatus.updateRequired);
  });

  test('HTML conflict response is not a compatibility failure', () async {
    await compatibility.check();
    respond = (request) async {
      request.response.statusCode = 409;
      request.response.write('<html>Conflict</html>');
      await request.response.close();
    };
    await transport.post('/protected/data');
    expect(compatibility.compatible, isTrue);
  });

  test(
    'invalid version code blocks work without confusing other 400 errors',
    () async {
      await compatibility.check();
      respond = (request) =>
          json(request, {'detail': 'validation'}, status: 400);
      await transport.post('/protected/data');
      expect(compatibility.compatible, isTrue);
      respond = (request) => json(request, {
        'code': 'CLIENT_VERSION_INVALID',
        'backendVersion': '1.5.0',
        'minClientVersion': '1.0.0',
      }, status: 400);
      await transport.post('/protected/data');
      expect(compatibility.status, CompatibilityStatus.error);
      await expectLater(
        transport.get('/protected/data'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  for (final status in [404, 200]) {
    test('missing or damaged app-info fails closed ($status)', () async {
      respond = (request) => json(request, {'data': {}}, status: status);
      await compatibility.check();
      expect(compatibility.status, CompatibilityStatus.error);
      expect(compatibility.compatible, isFalse);
    });
  }

  test(
    'late refusal from disposed server does not notify or affect new state',
    () async {
      await compatibility.check();
      final started = Completer<void>();
      final finish = Completer<void>();
      respond = (request) async {
        started.complete();
        await finish.future;
        await json(request, {
          'code': 'CLIENT_UPDATE_REQUIRED',
          'backendVersion': '2.0.0',
          'minClientVersion': '2.0.0',
        }, status: 409);
      };
      final pending = transport.get('/protected/data');
      await started.future;
      var notifications = 0;
      compatibility.addListener(() => notifications++);
      compatibility.dispose();
      // Supply a fresh provider for teardown, as a server switch would do.
      final oldTransport = transport;
      transport = HttpTransport(baseUrl: 'http://unused');
      compatibility = AppCompatibilityProvider(transport: transport);
      finish.complete();
      await pending;
      oldTransport.close();
      expect(notifications, 0);
      expect(compatibility.minimumVersion, isNull);
    },
  );

  test('malformed build metadata has no fallback version', () async {
    compatibility.dispose();
    compatibility = AppCompatibilityProvider(
      transport: transport,
      loadBuild: () async => ClientBuildInfo(version: 'bad', build: '42'),
    );
    await compatibility.check();
    expect(compatibility.status, CompatibilityStatus.error);
    expect(requests, isEmpty);
  });
}
