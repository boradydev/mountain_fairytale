import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_dialog.dart';

class FakeSettings extends ServerSettingsProvider {
  int checks = 0;
  bool available = true;
  FakeSettings(super.repository);

  @override
  Future<ServerConnectionResult> check(String url) async {
    checks++;
    return ServerConnectionResult(
      available,
      available
          ? 'Соединение установлено. Версия сервера: 1.0.0'
          : 'Не удалось подключиться.',
    );
  }
}

void main() {
  late FakeSettings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = FakeSettings(
      ServerSettingsRepository(
        await SharedPreferences.getInstance(),
        defaultUrl: 'http://default:8000',
      ),
    );
  });
  tearDown(() => settings.dispose());

  Future<void> open(
    WidgetTester tester, {
    void Function(String?)? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => ServerSettingsDialog(settings: settings),
                );
                onResult?.call(result);
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
  }

  testWidgets('field validation stays inside the field; reset does not save', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.tap(find.text('Проверить соединение'));
    await tester.pumpAndSettle();
    expect(settings.checks, 0);
    expect(find.textContaining('Укажите http://'), findsOneWidget);
    await tester.tap(find.text('Вернуть адрес по умолчанию'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      settings.defaultUrl,
    );
    expect(settings.url, settings.defaultUrl);
  });

  testWidgets('probe can be repeated and does not change the active URL', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField), 'http://new:8000');
    await tester.tap(find.text('Проверить соединение'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Версия сервера: 1.0.0'), findsOneWidget);
    await tester.tap(find.text('Проверить соединение'));
    await tester.pumpAndSettle();
    expect(settings.checks, 2);
    expect(settings.url, settings.defaultUrl);
  });

  testWidgets(
    'offline URL requires confirmation and can be saved voluntarily',
    (tester) async {
      settings.available = false;
      String? result;
      await open(tester, onResult: (value) => result = value);
      await tester.enterText(find.byType(TextFormField), 'http://new:8000/');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Сервер недоступен'), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.text('Сохранить всё равно'));
      await tester.pumpAndSettle();
      expect(find.text('Сменить сервер?'), findsOneWidget);
      await tester.tap(find.text('Сменить сервер'));
      await tester.pumpAndSettle();
      expect(result, 'http://new:8000');
    },
  );

  testWidgets('saving unchanged address closes without checking or switching', (
    tester,
  ) async {
    String? result;
    await open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(settings.checks, 0);
    expect(result, isNull);
    expect(find.byType(ServerSettingsDialog), findsNothing);
  });
}
