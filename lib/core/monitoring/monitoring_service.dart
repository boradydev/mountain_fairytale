import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/services.dart';

import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/core/monitoring/monitoring_config.dart';

/// Configuration loading never blocks the UI. No custom event queue is stored.
class MonitoringService {
  int _generation = 0;
  Timer? _retry;
  http.Client? _sender;
  HttpTransport? _loader;
  Future<void> _pending = Future.value();
  final Map<String, DateTime> _recent = {};

  Future<void> changeServer(String url) {
    final generation = ++_generation;
    _retry?.cancel();
    _sender?.close();
    _loader?.close();
    _recent.clear();
    _pending = _pending
        .then((_) async {
          if (generation != _generation) return;
          await Sentry.close();
          await _configure(url, generation);
        })
        .catchError((Object _) {
          // Diagnostics must not cause an application error of their own.
        });
    return _pending;
  }

  Future<void> _configure(String url, int generation) async {
    if (generation != _generation) return;
    final loader = HttpTransport(
      baseUrl: url,
      requestTimeout: const Duration(seconds: 4),
    );
    _loader = loader;
    try {
      final response = await loader.get('/public/monitoring/config');
      if (generation != _generation) return;
      if (response.statusCode != 200) {
        _scheduleRetry(url, generation);
        return;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final config = MonitoringConfig.parse(
        url,
        body['data'] as Map<String, dynamic>,
      );
      if (config == null) return;
      final package = await PackageInfo.fromPlatform();
      if (generation != _generation) return;
      final sender = _MonitoringClient(
        IOClient(
          HttpClient()..connectionTimeout = const Duration(seconds: 3),
        ),
      );
      _sender = sender;
      await SentryFlutter.init((options) {
        options
          ..dsn = config.dsn
          ..environment = config.environment
          ..release = 'flutter@${package.version}+${package.buildNumber}'
          ..httpClient = sender
          ..sendDefaultPii = false
          ..tracesSampleRate = 0
          ..autoInitializeNativeSdk = false
          ..enableNativeCrashHandling = false
          ..enableAutoSessionTracking = false
          ..enableAutoPerformanceTracing = false
          ..enableUserInteractionTracing = false
          ..enableUserInteractionBreadcrumbs = false
          ..attachScreenshot = false
          ..attachViewHierarchy = false
          ..maxBreadcrumbs = 0
          ..maxQueueSize = 30
          ..sendClientReports = false
          ..debug = false
          ..beforeSend = (event, hint) {
            if (generation != _generation) return null;
            final safe = privateMonitoringEvent(event);
            if (safe == null) return null;
            final signature =
                safe.exceptions
                    ?.map(
                      (e) =>
                          '${e.type}:${e.stackTrace?.frames.map((f) => '${f.fileName}:${f.lineNo}').join(',')}',
                    )
                    .join('|') ??
                '';
            final now = DateTime.now();
            if (_recent[signature]?.isAfter(
                  now.subtract(const Duration(minutes: 1)),
                ) ??
                false) {
              return null;
            }
            if (_recent.length >= 128) _recent.clear();
            _recent[signature] = now;
            return safe;
          };
      });
    } catch (_) {
      _scheduleRetry(url, generation);
    } finally {
      loader.close();
      if (identical(_loader, loader)) _loader = null;
    }
  }

  void _scheduleRetry(String url, int generation) {
    if (generation != _generation) return;
    _retry?.cancel();
    _retry = Timer(const Duration(minutes: 1), () {
      _pending = _pending.then((_) => _configure(url, generation));
    });
  }

  Future<void> dispose() async {
    _generation++;
    _retry?.cancel();
    _sender?.close();
    _loader?.close();
    await _pending;
    await Sentry.close();
  }
}

class _MonitoringClient extends http.BaseClient {
  _MonitoringClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    const timeout = Duration(seconds: 3);
    final response = await _inner.send(request).timeout(timeout);
    return http.StreamedResponse(
      response.stream.timeout(timeout),
      response.statusCode,
      headers: response.headers,
      request: response.request,
      reasonPhrase: response.reasonPhrase,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
    );
  }

  @override
  void close() => _inner.close();
}

bool isExpectedMonitoringError(Object? error) =>
    error is ApiException ||
    error is SocketException ||
    error is TimeoutException ||
    error is HttpException ||
    (error is PlatformException &&
        const {
          'cancelled',
          'canceled',
          'user_cancelled',
          'user_canceled',
        }.contains(error.code.toLowerCase()));

void reportUnexpected(Object error, StackTrace stack, String operation) {
  if (isExpectedMonitoringError(error)) return;
  unawaited(
    Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        scope.setTag('operation', operation);
      },
    ),
  );
}

SentryEvent? privateMonitoringEvent(SentryEvent event) {
  if (isExpectedMonitoringError(event.throwable)) return null;
  final exceptions = event.exceptions;
  if (exceptions == null || exceptions.isEmpty) return null;
  return SentryEvent(
    eventId: event.eventId,
    timestamp: event.timestamp,
    release: event.release,
    environment: event.environment,
    platform: event.platform,
    level: event.level,
    tags: {
      'component': 'flutter',
      if (const {
        'pdf_build',
        'pdf_print',
        'response_decode',
      }.contains(event.tags?['operation']))
        'operation': event.tags!['operation']!,
      if (RegExp(r'^[a-f0-9]{32}$').hasMatch(event.tags?['request_id'] ?? ''))
        'request_id': event.tags!['request_id']!,
    },
    exceptions: exceptions
        .map(
          (exception) => SentryException(
            type: exception.type,
            value: 'Unexpected application error',
            stackTrace: exception.stackTrace == null
                ? null
                : SentryStackTrace(
                    frames: exception.stackTrace!.frames
                        .map(
                          (frame) => SentryStackFrame(
                            fileName: frame.fileName
                                ?.replaceAll('\\', '/')
                                .split('/')
                                .last,
                            function: frame.function,
                            module: frame.module,
                            lineNo: frame.lineNo,
                            colNo: frame.colNo,
                            inApp: frame.inApp,
                          ),
                        )
                        .toList(),
                  ),
          ),
        )
        .toList(),
  );
}
