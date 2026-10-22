import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mountain_fairytale/features/app_updates/data/update_release.dart';
import 'package:mountain_fairytale/features/app_updates/update_service.dart';

class UpdateProvider extends ChangeNotifier {
  final UpdateService service;
  UpdateProvider(this.service);
  String installedVersion = '—';
  UpdateRelease? available;
  String? error;
  bool checking = false;
  bool ready = false;
  bool _disposed = false;
  Timer? _timer;

  Future<void> start() async {
    try {
      installedVersion = await service.installedVersion();
      if (UpdateService.publicKey.isEmpty) return;
      await service.initialize();
      ready = true;
      await check();
      if (!_disposed) {
        _timer = Timer.periodic(const Duration(hours: 4), (_) => check());
      }
    } catch (_) {
      error = 'Обновления недоступны в этой сборке.';
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> check() async {
    if (checking || !ready || _disposed) return;
    checking = true;
    error = null;
    notifyListeners();
    try {
      final release = await service.latest();
      available = release != null && release.isNewerThan(installedVersion)
          ? release
          : null;
    } catch (_) {
      error =
          'Не удалось проверить обновления. Проверьте подключение к интернету.';
    } finally {
      checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    service.close();
    super.dispose();
  }
}
