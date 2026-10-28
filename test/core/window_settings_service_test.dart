import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/core/window_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windowChannel = MethodChannel('window_manager');
  const screenChannel = MethodChannel(
    'dev.leanflutter.plugins/screen_retriever',
  );
  late SharedPreferences prefs;
  var maximized = false;
  var minimized = false;
  var failBounds = false;
  var failDisplays = false;
  var bounds = const Rect.fromLTWH(50, 60, 1300, 700);
  Completer<Map<String, double>>? boundsGate;
  late Completer<void> destroyed;
  var destroyCalls = 0;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'window_width': 1200.0,
      'window_height': 800.0,
    });
    prefs = await SharedPreferences.getInstance();
    maximized = minimized = failBounds = failDisplays = false;
    bounds = const Rect.fromLTWH(50, 60, 1300, 700);
    boundsGate = null;
    destroyed = Completer<void>();
    destroyCalls = 0;
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      switch (call.method) {
        case 'isMinimized':
          return minimized;
        case 'isMaximized':
          return maximized;
        case 'getBounds':
          if (failBounds) throw PlatformException(code: 'unavailable');
          return boundsGate?.future ??
              {
                'x': bounds.left,
                'y': bounds.top,
                'width': bounds.width,
                'height': bounds.height,
              };
        case 'destroy':
          destroyCalls++;
          if (!destroyed.isCompleted) destroyed.complete();
          return null;
      }
      throw StateError('Unexpected window method: ${call.method}');
    });
    messenger.setMockMethodCallHandler(screenChannel, (call) async {
      if (failDisplays) throw PlatformException(code: 'unavailable');
      return {
        'displays': [
          {
            'id': 'main',
            'size': {'width': 1920.0, 'height': 1080.0},
            'visiblePosition': {'dx': 0.0, 'dy': 0.0},
            'visibleSize': {'width': 1920.0, 'height': 1040.0},
          },
        ],
      };
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockMethodCallHandler(screenChannel, null);
  });

  test('maximized and minimized windows preserve ordinary geometry', () async {
    final settings = WindowSettingsService(prefs);
    await settings.saveNow();
    expect(prefs.getDouble('window_width'), 1300);
    expect(prefs.getDouble('window_x'), 50);
    maximized = true;
    bounds = const Rect.fromLTWH(-8, -8, 1936, 1096);
    await settings.saveNow();
    expect(prefs.getBool(WindowSettingsService.maximizedKey), isTrue);
    expect(prefs.getDouble('window_width'), 1300);
    expect(prefs.getDouble('window_x'), 50);
    minimized = true;
    maximized = false;
    await settings.saveNow();
    expect(prefs.getBool(WindowSettingsService.maximizedKey), isTrue);
    expect(prefs.getDouble('window_width'), 1300);
    minimized = false;
    bounds = const Rect.fromLTWH(80, 90, 1400, 750);
    await settings.saveNow();
    expect(prefs.getBool(WindowSettingsService.maximizedKey), isFalse);
    expect(prefs.getDouble('window_width'), 1400);
    expect(prefs.getDouble('window_x'), 80);
    // The native window may already be minimized by the time its preceding
    // maximize event is handled. Preserve that event's state for reopening.
    minimized = true;
    settings.onWindowMaximize();
    await settings.saveNow();
    expect(prefs.getBool(WindowSettingsService.maximizedKey), isTrue);
    expect(prefs.getDouble('window_width'), 1400);
  });

  test(
    'close waits for pending geometry and persists before native destroy',
    () async {
      final settings = WindowSettingsService(prefs);
      boundsGate = Completer<Map<String, double>>();
      settings.onWindowResized();
      await Future<void>.delayed(Duration.zero);
      settings.onWindowClose();
      settings.onWindowClose();
      await Future<void>.delayed(Duration.zero);
      expect(destroyCalls, 0);
      boundsGate!.complete({'x': 50, 'y': 60, 'width': 1300, 'height': 700});
      await destroyed.future;
      expect(destroyCalls, 1);
      expect(prefs.getDouble('window_width'), 1300);
      expect(prefs.getDouble('window_height'), 700);
      expect(prefs.getDouble('window_y'), 60);
    },
  );

  test(
    'unreachable positions and display failures keep previous geometry',
    () async {
      final settings = WindowSettingsService(prefs);
      bounds = const Rect.fromLTWH(5000, 5000, 1400, 750);
      await settings.saveNow();
      expect(prefs.getDouble('window_width'), 1200);
      expect(
        await WindowSettingsService.isPositionVisible(
          bounds.topLeft,
          bounds.size,
        ),
        isFalse,
      );
      failDisplays = true;
      bounds = const Rect.fromLTWH(50, 60, 1400, 750);
      await settings.saveNow();
      expect(prefs.getDouble('window_width'), 1200);
      expect(
        await WindowSettingsService.isPositionVisible(
          bounds.topLeft,
          bounds.size,
        ),
        isFalse,
      );
    },
  );

  test('native read failure does not prevent closing', () async {
    failBounds = true;
    WindowSettingsService(prefs).onWindowClose();
    await destroyed.future;
    expect(destroyCalls, 1);
    expect(prefs.getDouble('window_width'), 1200);
  });
}
