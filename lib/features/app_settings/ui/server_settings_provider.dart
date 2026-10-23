import 'package:flutter/foundation.dart';
import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';

class ServerSettingsProvider extends ChangeNotifier {
  final ServerSettingsRepository repository;
  late String _url = repository.load();
  bool _switching = false;

  ServerSettingsProvider(this.repository);

  String get url => _url;
  String get defaultUrl => repository.defaultUrl;
  Future<ServerConnectionResult> check(String url) => repository.check(url);

  Future<void> changeUrl(
    String value, {
    required Future<void> Function() endSession,
  }) async {
    final normalized = normalizeServerUrl(value);
    if (normalized == _url) return;
    if (_switching) throw StateError('Смена сервера уже выполняется.');
    _switching = true;
    try {
      // If secure storage cannot be cleared, keep the old server. An application
      // restart must never send saved credentials from server A to server B.
      await endSession();
      await repository.save(normalized);
      _url = normalized;
      notifyListeners();
    } finally {
      _switching = false;
    }
  }
}
