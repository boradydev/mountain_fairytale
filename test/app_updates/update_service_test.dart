import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mountain_fairytale/features/app_updates/update_service.dart';

void main() {
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
