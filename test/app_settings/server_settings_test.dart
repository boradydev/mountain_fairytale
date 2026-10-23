import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';

import '../auth/auth_fakes.dart';

void main() {
  test('normalizes trailing slash and accepts DNS, IPv4 and IPv6', () {
    expect(
      normalizeServerUrl(' http://192.168.0.26:8000/ '),
      'http://192.168.0.26:8000',
    );
    expect(normalizeServerUrl('https://EXAMPLE.COM/'), 'https://example.com');
    expect(normalizeServerUrl('http://[::1]:8000/'), 'http://[::1]:8000');
  });

  for (final value in [
    '',
    'localhost:8000',
    'ftp://server',
    'http://server/app/v1',
    'http://user:pass@server',
    'http://server?x=1',
    'http://server#part',
    'http://server:99999',
    'http://ser ver',
    'http://server\\path',
  ]) {
    test('rejects invalid server URL: $value', () {
      expect(() => normalizeServerUrl(value), throwsFormatException);
    });
  }

  test('same URL does not log out or write a preference', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = ServerSettingsProvider(
      ServerSettingsRepository(prefs, defaultUrl: 'http://old:8000'),
    );
    addTearDown(settings.dispose);
    await settings.changeUrl(
      'http://old:8000/',
      endSession: () async => fail('Unexpected logout'),
    );
    expect(prefs.containsKey(ServerSettingsRepository.preferenceKey), false);
  });

  test(
    'failed token cleanup leaves the selected and persisted server unchanged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = ServerSettingsProvider(
        ServerSettingsRepository(prefs, defaultUrl: 'http://old:8000'),
      );
      addTearDown(settings.dispose);
      await expectLater(
        settings.changeUrl(
          'http://new:8000',
          endSession: () async {
            throw StateError('secure storage unavailable');
          },
        ),
        throwsStateError,
      );
      expect(settings.url, 'http://old:8000');
      expect(prefs.containsKey(ServerSettingsRepository.preferenceKey), false);
    },
  );

  test('changing server clears real auth state and tokens before persisting new URL', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryTokenStorage();
    final service = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: storage,
    );
    final settings = ServerSettingsProvider(
      ServerSettingsRepository(prefs, defaultUrl: 'http://old:8000'),
    );
    addTearDown(service.dispose);
    addTearDown(settings.dispose);
    await service.login(username: 'manager', password: '');
    settings.addListener(() {
      expect(service.isAuthenticated, false);
      expect(storage.refresh, isNull);
      expect(storage.access, isNull);
    });
    await settings.changeUrl('http://new:8000/', endSession: service.logout);
    expect(settings.url, 'http://new:8000');
    expect(
      ServerSettingsRepository(prefs, defaultUrl: 'http://default:8000').load(),
      'http://new:8000',
    );
  });

  test('corrupt saved address falls back to build default', () async {
    SharedPreferences.setMockInitialValues({
      ServerSettingsRepository.preferenceKey: 'invalid',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(
      ServerSettingsRepository(prefs, defaultUrl: 'http://default:8000').load(),
      'http://default:8000',
    );
  });

  test(
    'health check uses the candidate server and sends no authorization',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = ServerSettingsRepository(
        await SharedPreferences.getInstance(),
        defaultUrl: 'http://old:8000',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final subscription = server.listen((request) async {
        expect(request.uri.path, '/health/ready');
        expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {'status': 'ready', 'version': '1.2.3'},
          }),
        );
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      final result = await repository.check('http://127.0.0.1:${server.port}');
      expect(result.available, true);
      expect(result.message, contains('1.2.3'));
      expect(repository.load(), 'http://old:8000');
    },
  );
}
