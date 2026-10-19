import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/clients/data/location_repository.dart';

import '../auth/auth_fakes.dart';

void main() {
  late RecordingTransport transport;
  late AuthServiceImpl auth;
  late LocationRepository repo;
  late DateTime now;

  HttpTransportResponse image(int value, [int size = 1]) =>
      HttpTransportResponse(
        statusCode: 200,
        body: jsonEncode({
          'data': {'png': base64Encode(List<int>.filled(size, value))},
        }),
      );

  setUp(() async {
    transport = RecordingTransport();
    auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    now = DateTime(2026, 10, 19);
    repo = LocationRepository(
      ApiClient(transport: transport, authService: auth, userAgent: 'test'),
      now: () => now,
    );
  });

  tearDown(() {
    auth.dispose();
    transport.close();
  });

  test(
    'shares pending requests and gets a fresh image after five minutes',
    () async {
      final pending = Completer<HttpTransportResponse>();
      transport.respond = (_) => pending.future;
      final first = repo.tile(17, 1, 1);
      final second = repo.tile(17, 1, 1);
      pending.complete(image(1));
      expect(await first, [1]);
      expect(await second, [1]);
      expect(transport.requests, hasLength(1));
      now = now.add(const Duration(minutes: 4));
      expect(await repo.tile(17, 1, 1), [1]);
      expect(transport.requests, hasLength(1));
      transport.respond = (_) async => image(2);
      now = now.add(const Duration(minutes: 1));
      expect(await repo.tile(17, 1, 1), [2]);
      expect(transport.requests, hasLength(2));
    },
  );

  test(
    'evicts the least recently used image instead of clearing the cache',
    () async {
      transport.respond = (_) async => image(1);
      for (var x = 0; x < 256; x++) {
        await repo.tile(17, x, 0);
      }
      await repo.tile(17, 0, 0); // Keep this image recently used.
      await repo.tile(17, 256, 0);
      final count = transport.requests.length;
      await repo.tile(17, 0, 0);
      await repo.tile(17, 255, 0);
      expect(transport.requests, hasLength(count));
      await repo.tile(17, 1, 0);
      expect(transport.requests, hasLength(count + 1));
    },
  );

  test('limits cached image bytes as well as entry count', () async {
    transport.respond = (_) async => image(1, 6 * 1024 * 1024);
    await repo.tile(17, 0, 0);
    await repo.tile(17, 1, 0);
    await repo.tile(17, 2, 0);
    await repo.tile(17, 1, 0);
    expect(transport.requests, hasLength(3));
    await repo.tile(17, 0, 0);
    expect(transport.requests, hasLength(4));
  });

  test('failed requests are removed so the next attempt can succeed', () async {
    transport.respond = (_) async =>
        HttpTransportResponse(statusCode: 503, body: '{}');
    await expectLater(repo.tile(17, 1, 1), throwsA(isA<ApiException>()));
    transport.respond = (_) async => image(3);
    expect(await repo.tile(17, 1, 1), [3]);
    expect(transport.requests, hasLength(2));
  });
}
