import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mountain_fairytale/features/app_updates/update_service.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';

void main() {
  for (final status in [401, 403, 429, 500, 503]) {
    test('HTTP $status is rejected and a later check recovers', () async {
      var failing = true;
      final service = UpdateService(
        client: MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'github.com');
          expect(request.url.path, endsWith('/download/update.json'));
          return failing
              ? http.Response('GitHub unavailable', status)
              : http.Response(
                  '{"schemaVersion":1,"version":"1.2.0",'
                  '"buildNumber":20,"description":"Recovery"}',
                  200,
                );
        }),
      );
      final updates = UpdateProvider(service)
        ..ready = true
        ..installedVersion = '1.1.2+65535';
      addTearDown(updates.dispose);
      await updates.check();
      expect(updates.error, contains('HTTP $status'));
      expect(updates.error, isNot(contains('подключение к интернету')));
      expect(updates.error, isNot(contains('Новых обновлений нет')));
      expect(updates.checking, isFalse);
      expect(updates.available, isNull);
      failing = false;
      await updates.check();
      expect(updates.error, isNull);
      expect(updates.available?.version, '1.2.0');
    });
  }

  test('a missing first release is a normal state', () async {
    final service = UpdateService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(service.close);
    expect(await service.latest(), isNull);
  });
  for (final failure in <String, Object>{
    'DNS lookup': const SocketException('Failed host lookup'),
    'connection refused': const SocketException('Connection refused'),
    'HTTP transport': http.ClientException('Connection closed'),
    'TLS': const HandshakeException('TLS connection failed'),
    'timeout': TimeoutException('Timed out'),
    'unexpected': StateError('Unexpected updater failure'),
  }.entries) {
    test('${failure.key} has a distinct diagnostic and recovers', () async {
      var failing = true;
      final service = UpdateService(
        client: MockClient((_) async {
          if (failing) throw failure.value;
          return http.Response('', 404);
        }),
      );
      final updates = UpdateProvider(service)..ready = true;
      addTearDown(updates.dispose);
      await updates.check();
      if (failure.key == 'timeout') {
        expect(updates.error, contains('не ответил вовремя'));
      } else if (failure.key == 'unexpected') {
        expect(
          updates.error,
          'Не удалось проверить обновления. Попробуйте ещё раз.',
        );
      } else {
        expect(updates.error, contains('подключение к интернету'));
      }
      expect(updates.error, isNot(contains('HTTP ')));
      expect(updates.checking, isFalse);
      failing = false;
      await updates.check();
      expect(updates.error, isNull);
      expect(updates.available, isNull);
    });
  }
  for (final response in [
    http.Response('<html>proxy error</html>', 200),
    http.Response('[]', 200),
    http.Response('x' * 64001, 200),
    http.Response('{"schemaVersion":2}', 200),
    http.Response(
      '{"schemaVersion":1,"version":"bad","buildNumber":1,"description":"x"}',
      200,
    ),
    http.Response.bytes([0xff, 0xfe], 200),
  ].indexed) {
    test(
      'damaged feed ${response.$1} is distinguished from network errors',
      () async {
        final updates = UpdateProvider(
          UpdateService(client: MockClient((_) async => response.$2)),
        )..ready = true;
        addTearDown(updates.dispose);
        await updates.check();
        expect(updates.error, contains('повреждённое описание'));
        expect(updates.error, isNot(contains('интернету')));
        expect(updates.checking, isFalse);
      },
    );
  }
  test(
    'a stalled metadata request really times out after the deadline',
    () async {
      final service = UpdateService(
        client: MockClient((_) => Completer<http.Response>().future),
      );
      addTearDown(service.close);
      await expectLater(service.latest(), throwsA(isA<TimeoutException>()));
    },
  );
  test(
    'a network error fails the check without invoking installation',
    () async {
      final service = UpdateService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(service.close);
      await expectLater(service.latest(), throwsA(isA<http.ClientException>()));
    },
  );
  test('invalid or oversized metadata is rejected', () async {
    for (final body in ['<html>proxy error</html>', '[]', 'x' * 64001]) {
      final service = UpdateService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(service.close);
      await expectLater(service.latest(), throwsFormatException);
    }
  });
}
