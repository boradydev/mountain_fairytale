import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/infra/http/api_exception.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';

import 'auth_fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late MemoryTokenStorage storage;
  late AuthServiceImpl service;
  late AuthProvider provider;

  setUp(() {
    repository = FakeAuthRepository();
    storage = MemoryTokenStorage();
    service = AuthServiceImpl(repository: repository, tokenStorage: storage);
    provider = AuthProvider(authService: service);
  });
  tearDown(() {
    provider.dispose();
    service.dispose();
  });

  test(
    'working UI is unavailable while local logout is clearing storage',
    () async {
      await provider.login(username: 'manager', password: '');
      storage.clearGate = Completer<void>();
      final exiting = provider.logout();
      expect(provider.isAuthenticated, isFalse);
      expect(provider.status, AuthStatus.initializing);
      storage.clearGate!.complete();
      await exiting;
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.currentUser, isNull);
    },
  );

  test(
    'old restore does not block the next employee login after logout',
    () async {
      storage.refresh = originalTokens.refreshToken;
      final gate = Completer<AuthTokensModel>();
      final started = Completer<void>();
      repository.onRefresh = (_) {
        started.complete();
        return gate.future;
      };
      final restoring = provider.restoreSession();
      await started.future;
      await provider.logout();
      expect(await provider.login(username: 'manager', password: ''), isTrue);
      gate.complete(renewedTokens);
      await restoring;
      expect(provider.status, AuthStatus.authenticated);
      expect(storage.refresh, originalTokens.refreshToken);
    },
  );

  test('old password change cannot update a new session error', () async {
    await provider.login(username: 'manager', password: '');
    final gate = Completer<void>();
    final started = Completer<void>();
    repository.onChangePassword = () {
      started.complete();
      return gate.future;
    };
    final changing = provider.changePassword(password: 'new');
    await started.future;
    await provider.logout();
    expect(await provider.login(username: 'manager', password: ''), isTrue);
    gate.completeError(
      const ApiException(statusCode: 500, message: 'Old error'),
    );
    expect(await changing, isFalse);
    expect(provider.status, AuthStatus.authenticated);
    expect(provider.error, isNull);
  });

  test(
    'unavailable restore offers retry without removing the refresh token',
    () async {
      storage.refresh = originalTokens.refreshToken;
      repository.onRefresh = (_) async => throw TimeoutException('Offline');
      await provider.restoreSession();
      expect(provider.status, AuthStatus.serverUnavailable);
      expect(provider.error, contains('Сервер недоступен'));
      expect(storage.refresh, originalTokens.refreshToken);
      repository.onRefresh = null;
      await provider.restoreSession();
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.currentUser?.username, 'manager');
    },
  );

  test(
    'login rejection has a readable message and keeps the login screen',
    () async {
      repository.onLogin = () async => throw const ApiException(
        statusCode: 401,
        message: 'Invalid credentials',
      );
      expect(
        await provider.login(username: 'manager', password: 'wrong'),
        isFalse,
      );
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.error, 'Неверный пользователь или пароль.');
      expect(provider.currentUser, isNull);
    },
  );

  test('loading users exposes an error and can be retried', () async {
    repository.usersError = TimeoutException('Offline');
    await provider.loadUsers();
    expect(provider.usersError, isNotNull);
    expect(provider.isLoadingUsers, isFalse);
    repository.usersError = null;
    await provider.loadUsers();
    expect(provider.usersError, isNull);
    expect(provider.users.single.username, 'manager');
  });

  test('double login submits only once', () async {
    final gate = Completer<AuthTokensModel>();
    final started = Completer<void>();
    repository.onLogin = () {
      started.complete();
      return gate.future;
    };
    final first = provider.login(username: 'manager', password: '');
    await started.future;
    expect(await provider.login(username: 'manager', password: ''), isFalse);
    expect(repository.loginCalls, 1);
    gate.complete(originalTokens);
    expect(await first, isTrue);
    expect(provider.isLoading, isFalse);
  });

  test('logout cannot be undone by an in-flight login', () async {
    final gate = Completer<AuthTokensModel>();
    final started = Completer<void>();
    repository.onLogin = () {
      started.complete();
      return gate.future;
    };
    final pending = provider.login(username: 'manager', password: '');
    await started.future;
    await provider.logout();
    gate.complete(originalTokens);
    expect(await pending, isFalse);
    expect(provider.status, AuthStatus.unauthenticated);
    expect(storage.refresh, isNull);
    expect(provider.isLoading, isFalse);
  });

  test('logout while restore is pending stays logged out', () async {
    storage.refresh = originalTokens.refreshToken;
    final gate = Completer<AuthTokensModel>();
    final started = Completer<void>();
    repository.onRefresh = (_) {
      started.complete();
      return gate.future;
    };
    final pending = provider.restoreSession();
    await started.future;
    await provider.logout();
    gate.complete(renewedTokens);
    await pending;
    expect(provider.status, AuthStatus.unauthenticated);
    expect(storage.refresh, isNull);
  });
}
