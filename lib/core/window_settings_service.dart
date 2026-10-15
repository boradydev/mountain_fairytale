import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Сервис-наблюдатель для автоматического сохранения размеров и позиции окна.
///
/// Класс отслеживает изменения геометрии окна приложения и сохраняет текущие
/// координаты и размеры в локальное хранилище [SharedPreferences].
///
/// Имеет встроенную защиту от частых обновлений (debounce) в 1 секунду,
/// чтобы избежать избыточной перезаписи данных на диск во время изменения размер
class WindowSettingsService extends WindowListener {
  static const Size defaultWindowSize = Size(1200, 800);
  static const Size minimumWindowSize = Size(1200, 600);

  Timer? _debounce;

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

  void _saveSettings() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (await windowManager.isMinimized()) return;

      final prefs = await SharedPreferences.getInstance();

      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();

      if (!isValidSize(size) || !await isPositionVisible(pos, size)) return;

      await prefs.setDouble('window_width', size.width);
      await prefs.setDouble('window_height', size.height);
      await prefs.setDouble('window_x', pos.dx);
      await prefs.setDouble('window_y', pos.dy);
    });
  }

  @override
  void onWindowResized() => _saveSettings();

  @override
  void onWindowMoved() => _saveSettings();
}
