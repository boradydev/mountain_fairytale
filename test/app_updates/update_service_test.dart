import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mountain_fairytale/features/app_updates/update_service.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';

void main() {
  for (final status in [403, 429, 500, 503]) {
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
      // Record current diagnostic wording: HTTP errors are reported as
      // connection errors. This is evidence for the block 6.1 audit.
      expect(updates.error, contains('подключение к интернету'));
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
