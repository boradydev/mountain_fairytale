import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/monitoring/monitoring_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This opt-in acceptance test intentionally uses actual local HTTP sockets.
  HttpOverrides.global = null;
  const live = bool.fromEnvironment('LIVE_MONITORING');
  test(
    'Flutter SDK sends a private event and stops on server switch',
    () async {
      const key = String.fromEnvironment('LIVE_MONITORING_KEY');
      const project = String.fromEnvironment('LIVE_MONITORING_PROJECT');
      const host = String.fromEnvironment(
        'LIVE_MONITORING_HOST',
        defaultValue: '10.77.50.11',
      );
      expect(key, isNotEmpty);
      PackageInfo.setMockInitialValues(
        appName: 'MountainFairytale',
        packageName: 'mountain_fairytale',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final receiver = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final forwarded = <String>[];
      final relay = HttpClient();
      receiver.listen((request) async {
        final bytes = await request.fold<List<int>>(
          [],
          (all, part) => all..addAll(part),
        );
        final decoded = request.headers.value('content-encoding') == 'gzip'
            ? gzip.decode(bytes)
            : bytes;
        forwarded.add(utf8.decode(decoded));
        final remote = await relay.openUrl(
          'POST',
          Uri.parse('http://$host:8080${request.uri}'),
        );
        request.headers.forEach((name, values) {
          if (!{'host', 'content-length', 'transfer-encoding'}.contains(name)) {
            remote.headers.set(name, values);
          }
        });
        remote.add(bytes);
        final response = await remote.close();
        request.response.statusCode = response.statusCode;
        request.response.add(
          await response.fold<List<int>>([], (all, part) => all..addAll(part)),
        );
        await request.response.close();
      });
      final api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var enabled = true;
      api.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {
              'enabled': enabled,
              'publicKey': key,
              'projectId': project,
              'port': receiver.port,
              'environment': 'acceptance-sdk',
            },
          }),
        );
        await request.response.close();
      });
      final service = MonitoringService();
      try {
        await service.changeServer('http://127.0.0.1:${api.port}');
        expect(Sentry.isEnabled, isTrue);
        final id = await Sentry.captureException(
          StateError('acceptance-private-secret-marker'),
          stackTrace: StackTrace.current,
        );
        expect(id, isNot(SentryId.empty()));
        expect(forwarded, hasLength(1));
        expect(
          forwarded.single,
          isNot(contains('acceptance-private-secret-marker')),
        );
        expect(forwarded.single, contains('flutter@1.0.0+1'));
        expect(forwarded.single, contains('stacktrace'));
        enabled = false;
        await service.changeServer('http://127.0.0.1:${api.port}');
        expect(Sentry.isEnabled, isFalse);
        await Sentry.captureException(StateError('disabled'));
        expect(forwarded, hasLength(1));
        // Event ID is public diagnostic metadata, never a credential.
        // ignore: avoid_print
        print('Flutter GlitchTip acceptance event: $id');
      } finally {
        await service.dispose();
        relay.close(force: true);
        await api.close(force: true);
        await receiver.close(force: true);
      }
    },
    skip: !live,
  );
}
