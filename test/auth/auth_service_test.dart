import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infra/auth/auth_errors.dart';
import 'package:mountain_fairytale/infra/auth/auth_service_impl.dart';
import 'package:mountain_fairytale/infra/http/api_client.dart';
import 'package:mountain_fairytale/infra/http/api_exception.dart';
import 'package:mountain_fairytale/infra/http/http_transport.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';

import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';

import 'auth_fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late MemoryTokenStorage storage;
  late AuthServiceImpl service;

  setUp(() {
    repository = FakeAuthRepository();
    storage = MemoryTokenStorage();
    service = AuthServiceImpl(repository: repository, tokenStorage: storage);
  });
  tearDown(() => service.dispose());

  Future<void> signIn() => service.login(username: 'manager', password: '');

  test(
    'late parallel 401 reuses refresh even if JWT strings are unchanged',
    () async {
      await signIn();
      repository.onRefresh = (_) async => originalTokens;
      final firstResponse = Completer<String>();
      final secondResponse = Completer<String>();
      var firstAttempts = 0;
      var secondAttempts = 0;
      final first = service.authenticatedRequest((_) {
        firstAttempts++;
        return firstAttempts == 1
            ? firstResponse.future
            : Future.value('first');
      });
      final second = service.authenticatedRequest((_) {
        secondAttempts++;
        return secondAttempts == 1
            ? secondResponse.future
            : Future.value('second');
      });
      firstResponse.completeError(
        const ApiException(statusCode: 401, message: 'Expired'),
      );
      expect(await first, 'first');
      secondResponse.completeError(
        const ApiException(statusCode: 401, message: 'Expired'),
      );
      expect(await second, 'second');
      expect(repository.refreshCalls, 1);
      expect(firstAttempts, 2);
      expect(secondAttempts, 2);
    },
  );

  test(
    'login is confirmed only after me and token persistence succeed',
    () async {
      await signIn();
      expect(service.currentUser?.employeeId, employee.employeeId);
      expect(service.isAuthenticated, isTrue);
      expect(repository.lastPassword, '');
      expect(storage.refresh, originalTokens.refreshToken);
    },
  );

  test(
    'failed token save cannot leave a partially authenticated session',
    () async {
      storage.failSave = true;
      await expectLater(signIn(), throwsStateError);
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
      expect(service.accessToken, isNull);
      expect(storage.refresh, isNull);
    },
  );

  test(
    'missing saved refresh opens login without requesting refresh',
    () async {
      expect(await service.restoreSession(), isFalse);
      expect(repository.refreshCalls, 0);
    },
  );

  test('restart restores the saved refresh and current user', () async {
    storage.refresh = originalTokens.refreshToken;
    expect(await service.restoreSession(), isTrue);
    expect(service.currentUser?.username, 'manager');
    expect(storage.refresh, renewedTokens.refreshToken);
  });

  for (final status in [401, 403]) {
    test('definitive refresh $status clears the saved session', () async {
      storage.refresh = originalTokens.refreshToken;
      repository.onRefresh = (_) async =>
          throw ApiException(statusCode: status, message: 'Denied');
      expect(await service.restoreSession(), isFalse);
      expect(storage.refresh, isNull);
      expect(service.isAuthenticated, isFalse);
    });
  }

  for (final error in <Object>[
    TimeoutException('Network timeout'),
    const ApiException(statusCode: 503, message: 'Unavailable'),
    const FormatException('Broken response'),
  ]) {
    test(
      'temporary refresh failure preserves credentials: ${error.runtimeType}',
      () async {
        storage.refresh = originalTokens.refreshToken;
        repository.onRefresh = (_) async => throw error;
        await expectLater(service.restoreSession(), throwsA(same(error)));
        expect(storage.refresh, originalTokens.refreshToken);
        expect(service.isAuthenticated, isFalse);
      },
    );
  }

  test(
    'profile failure during restore preserves the previous saved pair',
    () async {
      storage.refresh = originalTokens.refreshToken;
      repository.onGetMe = (_) async =>
          throw const ApiException(statusCode: 503, message: 'Unavailable');
      await expectLater(service.restoreSession(), throwsA(isA<ApiException>()));
      expect(storage.refresh, originalTokens.refreshToken);
      expect(service.currentUser, isNull);
    },
  );

  test(
    'parallel protected 401s share one refresh and retry each once',
    () async {
      await signIn();
      final started = Completer<void>();
      final gate = Completer<AuthTokensModel>();
      repository.onRefresh = (_) {
        started.complete();
        return gate.future;
      };
      var requests = 0;
      Future<String> request(String access) async {
        requests++;
        if (access == originalTokens.accessToken) {
          throw const ApiException(statusCode: 401, message: 'Expired');
        }
        return 'result';
      }

      final futures = List.generate(
        3,
        (_) => service.authenticatedRequest(request),
      );
      await started.future;
      gate.complete(renewedTokens);
      expect(await Future.wait(futures), ['result', 'result', 'result']);
      expect(repository.refreshCalls, 1);
      expect(requests, 6);
    },
  );

  test(
    'second 401 after refresh ends the session and notifies the provider',
    () async {
      final provider = AuthProvider(authService: service);
      addTearDown(provider.dispose);
      await provider.login(username: 'manager', password: '');
      var requests = 0;
      await expectLater(
        service.authenticatedRequest<String>((_) async {
          requests++;
          throw const ApiException(statusCode: 401, message: 'Denied');
        }),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 2);
      expect(repository.refreshCalls, 1);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(storage.refresh, isNull);
    },
  );

  test(
    'permission 403 does not refresh or terminate a valid session',
    () async {
      await signIn();
      await expectLater(
        service.authenticatedRequest<String>(
          (_) async =>
              throw const ApiException(statusCode: 403, message: 'Forbidden'),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(repository.refreshCalls, 0);
      expect(service.isAuthenticated, isTrue);
    },
  );

  test(
    'logout clears locally without waiting for an unreachable server',
    () async {
      await signIn();
      final serverResponse = Completer<void>();
      repository.onLogout = (_) => serverResponse.future;
      await service.logout();
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
      expect(storage.refresh, isNull);
      expect(repository.logoutAccess, originalTokens.accessToken);
      serverResponse.completeError(TimeoutException('Offline'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('refresh arriving after logout cannot restore a session', () async {
    await signIn();
    final started = Completer<void>();
    final gate = Completer<AuthTokensModel>();
    repository.onRefresh = (_) {
      started.complete();
      return gate.future;
    };
    final refresh = service.refresh();
    await started.future;
    await service.logout();
    gate.complete(renewedTokens);
    expect(await refresh, isFalse);
    expect(storage.refresh, isNull);
    expect(service.isAuthenticated, isFalse);
  });

  test('logout serializes behind an in-progress save and clears it', () async {
    await signIn();
    storage.saveStarted = Completer<void>();
    storage.saveGate = Completer<void>();
    final refresh = service.refresh();
    await storage.saveStarted!.future;
    final logout = service.logout();
    expect(service.isAuthenticated, isFalse);
    storage.saveGate!.complete();
    await logout;
    expect(await refresh, isFalse);
    expect(storage.refresh, isNull);
  });

  test('a response belonging to an old session is discarded', () async {
    await signIn();
    final response = Completer<String>();
    final started = Completer<void>();
    final operation = service.authenticatedRequest((_) {
      started.complete();
      return response.future;
    });
    final expectation = expectLater(
      operation,
      throwsA(isA<SessionChangedException>()),
    );
    await started.future;
    await service.logout();
    await signIn();
    response.complete('previous employee data');
    await expectation;
    expect(service.isAuthenticated, isTrue);
  });

  test('changing own password keeps the current session and tokens', () async {
    await signIn();
    await service.changePassword(password: '');
    expect(repository.lastPassword, '');
    expect(storage.refresh, originalTokens.refreshToken);
    expect(service.isAuthenticated, isTrue);
  });

  test('ApiClient unwraps list data and sends Bearer access', () async {
    await signIn();
    final transport = RecordingTransport();
    addTearDown(transport.close);
    transport.respond = (_) async => envelope(['item']);
    final api = ApiClient(
      transport: transport,
      authService: service,
      userAgent: 'Test',
    );
    expect(await api.getList('/protected/items'), ['item']);
    expect(
      transport.requests.single.headers?['Authorization'],
      'Bearer ${originalTokens.accessToken}',
    );
  });

  test('ApiClient retries a protected 401 using the refreshed token', () async {
    await signIn();
    final transport = RecordingTransport();
    addTearDown(transport.close);
    transport.respond = (request) async {
      if (request.headers?['Authorization'] ==
          'Bearer ${originalTokens.accessToken}') {
        return const HttpTransportResponse(
          statusCode: 401,
          body: '{"detail":"Unauthorized"}',
        );
      }
      return envelope({'value': 'ok'});
    };
    final api = ApiClient(
      transport: transport,
      authService: service,
      userAgent: 'Test',
    );
    expect((await api.get('/protected/items'))['data'], {'value': 'ok'});
    expect(repository.refreshCalls, 1);
    expect(transport.requests, hasLength(2));
  });
}
