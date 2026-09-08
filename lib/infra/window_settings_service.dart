import 'dart:async';

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
  Timer? _debounce;

  void _saveSettings() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      final prefs = await SharedPreferences.getInstance();

      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();

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
