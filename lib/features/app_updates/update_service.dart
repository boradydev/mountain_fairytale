import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:mountain_fairytale/features/app_updates/data/update_release.dart';

class UpdateService {
  static const releaseBase =
      'https://github.com/boradydev/mountain_fairytale/releases/latest/download';
  static const publicKey = String.fromEnvironment('UPDATE_PUBLIC_KEY');
  static const channel = MethodChannel('mountain_fairytale/updates');
  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> installedVersion() async =>
      await channel.invokeMethod<String>('version') ?? '0.0.0+0';

  Future<void> initialize() => channel.invokeMethod<void>('initialize', {
    'publicKey': publicKey,
    'feed': '$releaseBase/appcast.xml',
  });

  Future<UpdateRelease?> latest() async {
    final response = await _client
        .get(Uri.parse('$releaseBase/update.json'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return null; // First release not published.
    if (response.statusCode != 200 || response.bodyBytes.length > 64000) {
      throw const FormatException('Не удалось получить описание обновления');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Некорректное описание обновления');
    }
    return UpdateRelease.fromJson(json);
  }

  Future<void> checkWithUi() => channel.invokeMethod<void>('check');
  void close() => _client.close();
}
