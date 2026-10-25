import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/monitoring/monitoring_config.dart';
import 'package:mountain_fairytale/core/monitoring/monitoring_service.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  final config = <String, dynamic>{
    'enabled': true,
    'publicKey': 'a' * 32,
    'projectId': '2',
    'port': 8080,
  };

  test('LAN and VPN use the selected API host', () {
    final lan = MonitoringConfig.parse('http://192.168.1.25:8000', config)!;
    final vpn = MonitoringConfig.parse('http://10.77.50.11:8000', config)!;
    expect(Uri.parse(lan.dsn).host, '192.168.1.25');
    expect(Uri.parse(vpn.dsn).host, '10.77.50.11');
    expect(Uri.parse(vpn.dsn).port, 8080);
    expect(
      MonitoringConfig.parse('http://localhost:8000', {...config, 'port': 0}),
      isNull,
    );
    expect(
      MonitoringConfig.parse('http://localhost:8000', {
        ...config,
        'publicKey': 'bad@host',
      }),
      isNull,
    );
  });

  test('redaction keeps stack and release but removes private values', () {
    final event = SentryEvent(
      release: 'flutter@1.0.0+1',
      user: SentryUser(email: 'private-email'),
      message: SentryMessage('private-message'),
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'private-password',
          stackTrace: SentryStackTrace(
            frames: [
              SentryStackFrame(
                fileName: 'C:/Users/private-name/app.dart',
                function: 'save',
                lineNo: 12,
                vars: {'token': 'private-token'},
              ),
            ],
          ),
        ),
      ],
    );
    final clean = privateMonitoringEvent(event)!;
    expect(jsonEncode(clean.toJson()), isNot(contains('private')));
    expect(clean.exceptions!.single.stackTrace!.frames.single.function, 'save');
    expect(clean.release, event.release);
  });

  test('expected API and network failures are not operational crashes', () {
    for (final error in [
      const ApiException(statusCode: 401, message: 'private'),
      const SocketException('offline'),
      TimeoutException('offline'),
    ]) {
      expect(isExpectedMonitoringError(error), isTrue);
    }
  });

  test('unreachable configuration is nonfatal and can be replaced', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': {'enabled': false},
        }),
      );
      await request.response.close();
    });
    final service = MonitoringService();
    await service.changeServer('http://127.0.0.1:1');
    await service.changeServer('http://127.0.0.1:${server.port}');
    await service.dispose();
    await server.close(force: true);
  });
}
