import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Сервис-наблюдатель для автоматического сохранения размеров и позиции окна.
///
/// Класс отслеживает изменения геометрии окна приложения и сохраняет текущие
/// координаты и размеры в локальное хранилище [SharedPreferences].
///
/// Записывает настройки по завершении перемещения/изменения размера.
/// Последовательная запись и ожидание перед закрытием исключают потерю
/// последних изменений. Геометрия развёрнутого окна не заменяет обычную.
class WindowSettingsService extends WindowListener {
  WindowSettingsService(this._preferences);

  final SharedPreferences _preferences;
  static const Size defaultWindowSize = Size(1200, 800);
  static const Size minimumWindowSize = Size(1200, 600);

  static const maximizedKey = 'window_maximized';
  Future<void> _saving = Future.value();
  bool _closing = false;

  static bool isValidSize(Size size) =>
      size.width.isFinite &&
      size.height.isFinite &&
      size.width >= minimumWindowSize.width &&
      size.height >= minimumWindowSize.height;

  /// Rejects positions that would leave too little of the window reachable.
  static Future<bool> isPositionVisible(Offset position, Size size) async {
    if (!position.dx.isFinite || !position.dy.isFinite || !isValidSize(size)) {
      return false;
    }

    try {
      final displays = await screenRetriever.getAllDisplays();
      final windowBounds = position & size;

      return displays.any((display) {
        final displayBounds =
            (display.visiblePosition ?? Offset.zero) &
            (display.visibleSize ?? display.size);
        final overlap = windowBounds.intersect(displayBounds);
        return overlap.width >= 120 && overlap.height >= 40;
      });
    } catch (_) {
      // A display lookup failure should fall back to a centered window.
      return false;
    }
  }

  Future<void> saveNow({bool? maximized}) {
    final request = _saving.then((_) => _captureSettings(maximized: maximized));
    _saving = request.catchError((Object error, StackTrace stack) {
      debugPrint('Не удалось сохранить параметры окна: $error');
    });
    return request;
  }

  Future<void> _captureSettings({bool? maximized}) async {
    if (maximized != null) {
      await _preferences.setBool(maximizedKey, maximized);
    }
    if (await windowManager.isMinimized()) return;
    final isMaximized = await windowManager.isMaximized();
    await _preferences.setBool(maximizedKey, isMaximized);
    if (isMaximized) return;

    final bounds = await windowManager.getBounds();
    if (!isValidSize(bounds.size) ||
        !await isPositionVisible(bounds.topLeft, bounds.size) ||
        await windowManager.isMinimized() ||
        await windowManager.isMaximized()) {
      return;
    }

    await _preferences.setDouble('window_width', bounds.width);
    await _preferences.setDouble('window_height', bounds.height);
    await _preferences.setDouble('window_x', bounds.left);
    await _preferences.setDouble('window_y', bounds.top);
  }

  void _saveSettings({bool? maximized}) {
    if (!_closing)
      unawaited(saveNow(maximized: maximized).catchError((Object _) {}));
  }

  @override
  void onWindowResized() => _saveSettings();

  @override
  void onWindowMoved() => _saveSettings();

  @override
  void onWindowMaximize() => _saveSettings(maximized: true);

  @override
  void onWindowUnmaximize() => _saveSettings(maximized: false);

  @override
  void onWindowRestore() => _saveSettings();

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    try {
      await saveNow();
    } catch (_) {
      // saveNow already reports the error; closing must remain possible.
    } finally {
      await windowManager.destroy();
    }
  }
}
