import 'dart:convert';

import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

String normalizeServerUrl(String value) {
  final text = value.trim();
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      RegExp(r'\s|\\').hasMatch(text)) {
    throw const FormatException(
      'Укажите http:// или https://, имя сервера и порт без пути, логина и пароля.',
    );
  }
  if (uri.port < 1 || uri.port > 65535) {
    throw const FormatException('Порт должен быть от 1 до 65535.');
  }
  return uri.replace(host: uri.host.toLowerCase(), path: '').toString();
}

class ServerConnectionResult {
  final bool available;
  final String message;
  const ServerConnectionResult(this.available, this.message);
}

class ServerSettingsRepository {
  static const preferenceKey = 'api_server_url';
  final SharedPreferences preferences;
  final String defaultUrl;

  ServerSettingsRepository(this.preferences, {required String defaultUrl})
    : defaultUrl = normalizeServerUrl(defaultUrl);

  String load() {
    final saved = preferences.getString(preferenceKey);
    if (saved != null) {
      try {
        return normalizeServerUrl(saved);
      } on FormatException {
        // A broken old preference must not prevent access to settings.
      }
    }
    return defaultUrl;
  }

  Future<void> save(String url) async {
    if (!await preferences.setString(preferenceKey, url)) {
      throw StateError('Не удалось сохранить адрес сервера.');
    }
  }

  Future<ServerConnectionResult> check(String url) async {
    // Separate transport: probes never carry authorization or switch the active API.
    final transport = HttpTransport(
      baseUrl: normalizeServerUrl(url),
      requestTimeout: const Duration(seconds: 5),
    );
    try {
      final response = await transport.get('/health/ready');
      if (response.statusCode == 503) {
        return const ServerConnectionResult(
          false,
          'Сервер отвечает, но пока не готов к работе.',
        );
      }
      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      if (response.statusCode != 200 ||
          data is! Map ||
          data['status'] != 'ready' ||
          data['version'] is! String) {
        return const ServerConnectionResult(
          false,
          'По этому адресу не найден готовый API приложения.',
        );
      }
      return ServerConnectionResult(
        true,
        'Соединение установлено. Версия сервера: ${data['version']}',
      );
    } catch (_) {
      return const ServerConnectionResult(
        false,
        'Не удалось подключиться. Проверьте адрес, сеть и запуск сервера.',
      );
    } finally {
      transport.close();
    }
  }
}
