import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/infra/repos/auth/repo_impl.dart';
import 'package:mountain_fairytale/infra/repos/auth/sources/api_data_source.dart';

import 'auth_fakes.dart';

void main() {
  late RecordingTransport transport;
  late AuthRepositoryImpl repository;

  setUp(() {
    transport = RecordingTransport();
    repository = AuthRepositoryImpl(
      dataSource: AuthApiDataSource(transport: transport),
    );
  });
  tearDown(() => transport.close());

  test(
    'public users reads data.usernames and preserves server order',
    () async {
      transport.respond = (_) async => envelope({
        'usernames': ['z-manager', 'admin', 'a-manager'],
      });
      final users = await repository.getUsers();
      expect(users.map((user) => user.username), [
        'z-manager',
        'admin',
        'a-manager',
      ]);
      expect(transport.requests.single.path, '/public/auth/users');
      expect(transport.requests.single.headers, isNull);
    },
  );

  test('empty usernames is a valid empty list', () async {
    transport.respond = (_) async => envelope({'usernames': <String>[]});
    expect(await repository.getUsers(), isEmpty);
  });

  test(
    'login unwraps camelCase tokens and sends the empty password unchanged',
    () async {
      transport.respond = (_) async => envelope(originalTokens.toJson());
      final tokens = await repository.login(username: 'manager', password: '');
      expect(tokens.accessToken, originalTokens.accessToken);
      expect(tokens.refreshToken, originalTokens.refreshToken);
      final request = transport.requests.single;
      expect(request.path, '/public/auth/login');
      expect(request.body, {'username': 'manager', 'password': ''});
      expect(request.headers, isNull);
    },
  );

  test(
    'refresh sends refreshToken without triggering an automatic retry',
    () async {
      transport.respond = (_) async => const HttpTransportResponse(
        statusCode: 401,
        body: '{"detail":"Invalid credentials"}',
      );
      await expectLater(
        repository.refresh(refreshToken: 'expired'),
        throwsA(isA<ApiException>()),
      );
      expect(transport.requests, hasLength(1));
      expect(transport.requests.single.path, '/public/auth/refresh');
      expect(transport.requests.single.body, {'refreshToken': 'expired'});
    },
  );

  test('me reads identity and uses Bearer access token', () async {
    transport.respond = (_) async => envelope({
      'employeeId': employee.employeeId,
      'username': 'renamed',
      'role': 'admin',
    });
    final user = await repository.getMe(accessToken: 'access');
    expect(user.employeeId, employee.employeeId);
    expect(user.username, 'renamed');
    expect(user.isAdmin, isTrue);
    expect(transport.requests.single.path, '/protected/me');
    expect(transport.requests.single.headers, {
      'Authorization': 'Bearer access',
    });
  });

  test('password change sends only password; logout has no body', () async {
    transport.respond = (_) async => envelope(null);
    await repository.changePassword(accessToken: 'access', password: '');
    await repository.logout(accessToken: 'access');
    expect(transport.requests[0].method, 'PUT');
    expect(transport.requests[0].path, '/protected/me/change-password');
    expect(transport.requests[0].body, {'password': ''});
    expect(transport.requests[1].method, 'POST');
    expect(transport.requests[1].path, '/protected/me/logout');
    expect(transport.requests[1].body, isNull);
    for (final request in transport.requests) {
      expect(request.headers, {'Authorization': 'Bearer access'});
    }
  });

  test('validation detail array is parsed without assuming a string', () async {
    transport.respond = (_) async => const HttpTransportResponse(
      statusCode: 422,
      body: '{"detail":[{"loc":["body","password"],"msg":"Too long","type":"string_too_long"}]}',
    );
    await expectLater(
      repository.login(username: 'manager', password: ''),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 422)
            .having((error) => error.message, 'message', 'Too long'),
      ),
    );
  });

  test('unexpected users response is not mistaken for an empty list', () async {
    transport.respond = (_) async => envelope({
      'usernames': ['manager', 42],
    });
    await expectLater(repository.getUsers(), throwsFormatException);
  });
}
