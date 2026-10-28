import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/network/client_build_info.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_errors.dart';

enum CompatibilityStatus { checking, compatible, updateRequired, error }

class AppCompatibilityProvider extends ChangeNotifier {
  final HttpTransport transport;
  final Future<ClientBuildInfo> Function() loadBuild;
  CompatibilityStatus status = CompatibilityStatus.checking;
  String? backendVersion;
  String? minimumVersion;
  String? error;
  int workEpoch = 0;
  bool checking = false;
  bool _disposed = false;
  int _responseRevision = 0;

  AppCompatibilityProvider({
    required this.transport,
    Future<ClientBuildInfo> Function()? loadBuild,
  }) : loadBuild = loadBuild ?? ClientBuildInfo.load {
    transport.beforeRequest = _guardRequest;
    transport.onResponse = _inspectResponse;
  }

  bool get compatible => status == CompatibilityStatus.compatible;
  ClientBuildInfo? get installed => transport.clientBuild;

  void _guardRequest(String path) {
    final route = Uri.parse(path).path;
    final working =
        route.startsWith('/protected/') ||
        route.startsWith('/admin/') ||
        route.startsWith('/public/auth/');
    if (_disposed || (working && !compatible)) {
      throw ApiException(
        statusCode: status == CompatibilityStatus.updateRequired ? 409 : 400,
        message: error ?? 'Проверка совместимости приложения не завершена.',
      );
    }
  }

  void _setStatus(CompatibilityStatus value) {
    if (compatible && value != CompatibilityStatus.compatible) workEpoch++;
    status = value;
  }

  void _inspectResponse(HttpTransportResponse response) {
    if (_disposed ||
        (response.statusCode != 409 && response.statusCode != 400)) {
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      // A proxy or ordinary validation error is not a version requirement.
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final update =
        response.statusCode == 409 &&
        decoded['code'] == 'CLIENT_UPDATE_REQUIRED';
    final invalid =
        response.statusCode == 400 &&
        decoded['code'] == 'CLIENT_VERSION_INVALID';
    if (!update && !invalid) return;
    try {
      _responseRevision++;
      _readVersions(decoded);
      error = update
          ? 'Для работы требуется обновить приложение до версии $minimumVersion или новее.'
          : 'Не удалось определить версию приложения. Установите актуальную сборку.';
      _setStatus(
        update ? CompatibilityStatus.updateRequired : CompatibilityStatus.error,
      );
      notifyListeners();
    } on FormatException {
      _responseRevision++;
      error = 'Не удалось прочитать требование сервера к версии приложения.';
      _setStatus(CompatibilityStatus.error);
      notifyListeners();
    }
  }

  void _readVersions(Map<String, dynamic> data) {
    final minimum = data['minClientVersion'];
    final backend = data['backendVersion'];
    if (minimum is! String || backend is! String) {
      throw const FormatException('Invalid app-info');
    }
    ClientBuildInfo.parseVersion(minimum);
    ClientBuildInfo.parseVersion(backend);
    minimumVersion = minimum;
    backendVersion = backend;
  }

  Future<void> check() async {
    if (_disposed || checking) return;
    checking = true;
    final revision = _responseRevision;
    final wasRequired = status == CompatibilityStatus.updateRequired;
    error = null;
    notifyListeners();
    try {
      transport.clientBuild ??= await loadBuild();
      if (_disposed) return;
      final response = await transport.get('/public/app-info');
      if (_disposed || revision != _responseRevision) return;
      if (response.statusCode != 200) {
        throw ApiException.fromResponse(
          statusCode: response.statusCode,
          body: response.body,
          requestId: response.requestId,
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid app-info envelope');
      }
      _readVersions(body['data'] as Map<String, dynamic>);
      if (installed!.supportsMinimum(minimumVersion!)) {
        _setStatus(CompatibilityStatus.compatible);
      } else {
        error =
            'Для работы требуется обновить приложение до версии $minimumVersion или новее.';
        _setStatus(CompatibilityStatus.updateRequired);
      }
    } catch (exception) {
      if (_disposed || revision != _responseRevision) return;
      error = authErrorMessage(exception);
      _setStatus(
        wasRequired
            ? CompatibilityStatus.updateRequired
            : CompatibilityStatus.error,
      );
    } finally {
      checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // A late response from the old server must not reach a new app instance.
    transport.onResponse = null;
    super.dispose();
  }
}
