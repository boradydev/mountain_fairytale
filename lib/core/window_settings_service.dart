import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

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
  WindowSettingsService(this._preferences) {
    for (final key in _keys) {
      _persisted[key] = _preferences.get(key);
    }
  }

  final SharedPreferences _preferences;
  static const Size defaultWindowSize = Size(1200, 800);
  static const Size minimumWindowSize = Size(1200, 600);

  static const maximizedKey = 'window_maximized';
  static const _keys = [
    'window_width',
    'window_height',
    'window_x',
    'window_y',
    maximizedKey,
  ];
  final Map<String, Object?> _persisted = {};
  Future<void>? _saving;
  Timer? _debounce;
  bool _dirty = false;
  bool? _pendingMaximized;
  bool _closing = false;

  static bool isValidSize(Size size) =>
      size.width.isFinite &&
      size.height.isFinite &&
      size.width >= minimumWindowSize.width &&
      size.height >= minimumWindowSize.height;

  /// Rejects positions that would leave too little of the window reachable.
  static Future<bool> isPositionVisible(Offset position, Size size) async {
    if (!position.dx.isFinite ||
        !position.dy.isFinite ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
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
        return size.width >=
                math.min(minimumWindowSize.width, displayBounds.width) &&
            size.height >=
                math.min(minimumWindowSize.height, displayBounds.height) &&
            overlap.width >= 120 &&
            overlap.height >= 40;
      });
    } catch (_) {
      // A display lookup failure should fall back to a centered window.
      return false;
    }
  }

  /// Fit ordinary bounds to a currently available monitor's work area.
  static Future<({Size size, Size minimumSize, Offset? position})>
  restoreGeometry(Size size, Offset? position) async {
    if (!isValidSize(size)) size = defaultWindowSize;
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (displays.isEmpty) throw StateError('No displays');
      final areas = displays
          .map(
            (d) =>
                (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size),
          )
          .toList();
      var area = areas.first;
      var bestOverlap = 0.0;
      if (position != null && await isPositionVisible(position, size)) {
        for (final candidate in areas) {
          final overlap = (position & size).intersect(candidate);
          final surface =
              math.max(0.0, overlap.width) * math.max(0.0, overlap.height);
          if (surface > bestOverlap) {
            bestOverlap = surface;
            area = candidate;
          }
        }
      } else {
        position = null;
      }
      final minimum = Size(
        math.min(minimumWindowSize.width, area.width),
        math.min(minimumWindowSize.height, area.height),
      );
      size = Size(
        size.width.clamp(minimum.width, area.width),
        size.height.clamp(minimum.height, area.height),
      );
      position = position == null
          ? Offset(
              area.left + (area.width - size.width) / 2,
              area.top + (area.height - size.height) / 2,
            )
          : Offset(
              position.dx.clamp(area.left, area.right - size.width),
              position.dy.clamp(area.top, area.bottom - size.height),
            );
      return (size: size, minimumSize: minimum, position: position);
    } catch (_) {
      return (size: size, minimumSize: minimumWindowSize, position: null);
    }
  }

  Future<void> saveNow({bool? maximized}) {
    if (_closing) return _saving ?? Future.value();
    _debounce?.cancel();
    _dirty = true;
    if (maximized != null) _pendingMaximized = maximized;
    return _saving ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_dirty && !_closing) {
        _dirty = false;
        final maximized = _pendingMaximized;
        _pendingMaximized = null;
        try {
          await _captureSettings(maximized: maximized);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Не удалось сохранить параметры окна: $error');
          }
        }
      }
    } finally {
      _saving = null;
    }
  }

  Future<Map<String, Object>> _readSettings({bool? maximized}) async {
    if (await windowManager.isMinimized()) {
      return {maximizedKey: ?maximized};
    }
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) return {maximizedKey: true};
    final bounds = await windowManager.getBounds();
    final visible = await isPositionVisible(bounds.topLeft, bounds.size);
    // Recheck native state after asynchronous geometry/display reads.
    if (await windowManager.isMinimized()) {
      return {maximizedKey: ?maximized};
    }
    if (await windowManager.isMaximized()) return {maximizedKey: true};
    return {
      maximizedKey: false,
      if (visible) ...{
        'window_width': bounds.width,
        'window_height': bounds.height,
        'window_x': bounds.left,
        'window_y': bounds.top,
      },
    };
  }

  Future<void> _writeSettings(Map<String, Object> values) async {
    for (final entry in values.entries) {
      if (_persisted[entry.key] == entry.value) continue;
      final value = entry.value;
      final success = value is bool
          ? await _preferences.setBool(entry.key, value)
          : await _preferences.setDouble(entry.key, value as double);
      if (!success) {
        throw StateError('Window setting write failed: ${entry.key}');
      }
      _persisted[entry.key] = value;
    }
  }

  Future<void> _captureSettings({bool? maximized}) async {
    await _writeSettings(await _readSettings(maximized: maximized));
  }

  void _scheduleGeometry() {
    if (_closing) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(saveNow());
    });
  }

  @override
  void onWindowResized() => _scheduleGeometry();

  @override
  void onWindowMoved() => _scheduleGeometry();

  @override
  void onWindowMaximize() {
    unawaited(saveNow(maximized: true));
  }

  @override
  void onWindowUnmaximize() {
    unawaited(saveNow(maximized: false));
  }

  @override
  void onWindowRestore() {
    unawaited(saveNow());
  }

  void _logDuration(String phase, Stopwatch watch) {
    if (kDebugMode) {
      debugPrint('Window close: $phase ${watch.elapsedMilliseconds} ms');
    }
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    _debounce?.cancel();
    _dirty = false;
    final watch = Stopwatch()..start();
    try {
      await _saving;
      _logDuration('wait', watch);
      watch.reset();
      final values = await _readSettings(maximized: _pendingMaximized);
      _logDuration('read', watch);
      watch.reset();
      await _writeSettings(values);
      _logDuration('write', watch);
    } catch (error) {
      if (kDebugMode) debugPrint('Window close: settings failed: $error');
    } finally {
      await windowManager.destroy();
    }
  }
}
