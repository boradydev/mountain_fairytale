import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

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
  var reads = 0;
  var displayWidth = 1920.0;
  var displayHeight = 1040.0;
  late RecordingStore store;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'window_width': 1200.0,
      'window_height': 800.0,
    });
    store = RecordingStore();
    SharedPreferencesStorePlatform.instance = store;
    prefs = await SharedPreferences.getInstance();
    reads = 0;
    displayWidth = 1920;
    displayHeight = 1040;
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
          reads++;
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
            'visibleSize': {'width': displayWidth, 'height': displayHeight},
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
      unawaited(settings.saveNow());
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
  for (final event in ['move', 'resize', 'mixed']) {
    testWidgets('$event burst is debounced and keeps last bounds', (
      tester,
    ) async {
      final settings = WindowSettingsService(prefs);
      for (var i = 0; i < 20; i++) {
        if (event == 'resize' || (event == 'mixed' && i.isEven)) {
          settings.onWindowResized();
        } else {
          settings.onWindowMoved();
        }
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(reads, 0);
      bounds = const Rect.fromLTWH(100, 110, 1400, 750);
      await tester.pump(const Duration(milliseconds: 399));
      await tester.pump();
      expect(reads, 1);
      expect(prefs.getDouble('window_x'), 100);
      expect(store.writes.length, 5);
    });
  }

  test(
    'unchanged values are not written and failed writes are retried',
    () async {
      final settings = WindowSettingsService(prefs);
      store.fail = true;
      await settings.saveNow();
      store.fail = false;
      await settings.saveNow();
      expect(
        store.writes.where((key) => key == 'flutter.window_maximized').length,
        2,
      );
      final count = store.writes.length;
      await settings.saveNow();
      expect(store.writes.length, count);
    },
  );

  test('in-flight requests coalesce to one latest capture', () async {
    final settings = WindowSettingsService(prefs);
    boundsGate = Completer<Map<String, double>>();
    final saving = settings.saveNow();
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 50; i++) {
      unawaited(settings.saveNow());
    }
    final gate = boundsGate!;
    boundsGate = null;
    bounds = const Rect.fromLTWH(100, 120, 1400, 750);
    gate.complete({'x': 50, 'y': 60, 'width': 1300, 'height': 700});
    await saving;
    expect(reads, 2);
    expect(prefs.getDouble('window_x'), 100);
    expect(prefs.getDouble('window_width'), 1400);
  });

  testWidgets('close cancels debounce and rejects subsequent events', (
    tester,
  ) async {
    final settings = WindowSettingsService(prefs);
    settings.onWindowMoved();
    settings.onWindowClose();
    settings.onWindowClose();
    settings.onWindowRestore();
    await tester.pump();
    expect(destroyCalls, 1);
    expect(reads, 1);
    expect(prefs.getDouble('window_y'), 60);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 1);
  });

  test(
    'small monitor permits physically available minimum and saves it',
    () async {
      displayWidth = 1024;
      displayHeight = 560;
      final geometry = await WindowSettingsService.restoreGeometry(
        const Size(1300, 800),
        null,
      );
      expect(geometry.minimumSize, const Size(1024, 560));
      expect(geometry.size, const Size(1024, 560));
      bounds = geometry.position! & geometry.size;
      await WindowSettingsService(prefs).saveNow();
      expect(prefs.getDouble('window_width'), 1024);
    },
  );

  test(
    'close waits for actual storage write then captures latest state',
    () async {
      final settings = WindowSettingsService(prefs);
      store.gate = Completer<void>();
      unawaited(settings.saveNow());
      await Future<void>.delayed(Duration.zero);
      settings.onWindowClose();
      bounds = const Rect.fromLTWH(150, 160, 1400, 750);
      expect(destroyCalls, 0);
      store.gate!.complete();
      await destroyed.future;
      expect(reads, 2);
      expect(prefs.getDouble('window_x'), 150);
    },
  );

  test('write failure still destroys window', () async {
    store.fail = true;
    WindowSettingsService(prefs).onWindowClose();
    await destroyed.future;
    expect(destroyCalls, 1);
  });

  test(
    'disconnected monitor is centered and oversized bounds fit work area',
    () async {
      final geometry = await WindowSettingsService.restoreGeometry(
        const Size(2500, 1500),
        const Offset(3000, 0),
      );
      expect(geometry.size, const Size(1920, 1040));
      expect(geometry.position, Offset.zero);
      final centered = await WindowSettingsService.restoreGeometry(
        const Size(1200, 800),
        const Offset(3000, 0),
      );
      expect(centered.position, const Offset(360, 120));
      final clamped = await WindowSettingsService.restoreGeometry(
        const Size(1300, 700),
        const Offset(1800, 100),
      );
      expect(clamped.position, const Offset(620, 100));
    },
  );
}

class RecordingStore extends InMemorySharedPreferencesStore {
  RecordingStore()
    : super.withData({
        'flutter.window_width': 1200.0,
        'flutter.window_height': 800.0,
      });
  final List<String> writes = [];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes.add(key);
    await gate?.future;
    if (fail) return false;
    return super.setValue(valueType, key, value);
  }
}
