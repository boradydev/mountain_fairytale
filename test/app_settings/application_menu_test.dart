import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mountain_fairytale/app/application_menu_button.dart';
import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_dialog.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';

import '../auth/auth_fakes.dart';
import '../app_updates/update_button_test.dart' show FakeUpdates;

void main() {
  late ServerSettingsProvider settings;
  late AuthServiceImpl auth;
  late UpdateProvider updates;
  late FakeUpdates updateService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = ServerSettingsProvider(
      ServerSettingsRepository(
        await SharedPreferences.getInstance(),
        defaultUrl: 'http://localhost:8000',
      ),
    );
    auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    updateService = FakeUpdates();
    updates = UpdateProvider(updateService)
      ..ready = true
      ..installedVersion = '1.0.0+1';
  });
  tearDown(() {
    settings.dispose();
    auth.dispose();
    updates.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    GlobalKey<NavigatorState>? navigator,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: updates),
          ListenableProvider<AuthService>.value(value: auth),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            appBar: AppBar(actions: const [ApplicationMenuButton()]),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'one application menu contains both actions and opens connection settings',
    (tester) async {
      await show(tester);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
      expect(find.byIcon(Icons.system_update_alt), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Настройки подключения…'), findsOneWidget);
      expect(find.text('Проверить обновления…'), findsOneWidget);
      await tester.tap(find.text('Настройки подключения…'));
      await tester.pumpAndSettle();
      expect(find.byType(ServerSettingsDialog), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        false,
      );
    },
  );

  testWidgets(
    'authenticated connection is read-only until explicit change action',
    (tester) async {
      await tester.runAsync(
        () => auth.login(username: 'manager', password: ''),
      );
      await show(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Настройки подключения…'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        true,
      );
      expect(find.text('Вернуть адрес по умолчанию'), findsNothing);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        false,
      );
      await tester.tap(find.text('Сменить сервер и выйти…'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        false,
      );
      expect(auth.isAuthenticated, true);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        true,
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, true);
      expect(settings.url, 'http://localhost:8000');
    },
  );

  testWidgets(
    'available release adds a dot and update action retains confirmation',
    (tester) async {
      await updates.check();
      await show(tester);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, true);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить обновления…'));
      await tester.pumpAndSettle();
      expect(find.text('Обновление 1.1.0'), findsOneWidget);
      expect(updateService.installerChecks, 0);
      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
      expect(updateService.installerChecks, 0);
    },
  );

  testWidgets('an editor route prevents opening the application menu', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await show(tester, navigator: navigator);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(appBar: AppBar(actions: const [ApplicationMenuButton()])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    expect(find.text('Настройки подключения…'), findsNothing);
    expect(updateService.feedChecks, 0);
  });
}
