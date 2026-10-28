import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mountain_fairytale/core/network/client_build_info.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_provider.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_screen.dart';
import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_dialog.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/auth/ui/login_screen.dart';
import 'package:mountain_fairytale/main.dart';
import 'package:mountain_fairytale/shared/providers/locale_provider.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';

import '../auth/auth_fakes.dart';
import '../app_updates/update_button_test.dart' show FakeUpdates;

class InfoTransport extends HttpTransport {
  InfoTransport() : super(baseUrl: 'http://test');
  @override
  Future<HttpTransportResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async => const HttpTransportResponse(
    statusCode: 200,
    body: '{"data":{"backendVersion":"1.0.0","minClientVersion":"1.0.0"}}',
  );
}

void main() {
  testWidgets(
    'hot refusal discards modal form; update, retry and settings remain usable',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            (_) async => null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('window_manager'),
              null,
            ),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final transport = InfoTransport();
      final compatibility = AppCompatibilityProvider(
        transport: transport,
        loadBuild: () async => ClientBuildInfo(version: '1.0.0', build: '1'),
      );
      await compatibility.check();
      final service = FakeUpdates();
      final updates = UpdateProvider(service)
        ..ready = true
        ..installedVersion = '1.0.0+1';
      final auth = AuthServiceImpl(
        repository: FakeAuthRepository(),
        tokenStorage: MemoryTokenStorage(),
      );
      final authProvider = AuthProvider(authService: auth);
      final settings = ServerSettingsProvider(
        ServerSettingsRepository(prefs, defaultUrl: 'http://test'),
      );
      final theme = ThemeProvider(prefs);
      final locale = LocaleProvider(prefs);
      addTearDown(() {
        compatibility.dispose();
        transport.close();
        updates.dispose();
        authProvider.dispose();
        auth.dispose();
        settings.dispose();
        theme.dispose();
        locale.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: compatibility),
            ChangeNotifierProvider.value(value: updates),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: authProvider),
            ListenableProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: locale),
          ],
          child: const MyApp(sessionProviders: []),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      final oldContext = tester.element(find.byType(LoginScreen));
      showDialog<void>(
        context: oldContext,
        builder: (_) => const AlertDialog(
          title: Text('Несохранённый документ'),
          content: TextField(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'черновик');
      transport.onResponse!(
        HttpTransportResponse(
          statusCode: 409,
          body: jsonEncode({
            'code': 'CLIENT_UPDATE_REQUIRED',
            'backendVersion': '2.0.0',
            'minClientVersion': '1.1.0',
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Несохранённый документ'), findsNothing);
      expect(find.text('черновик'), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(AppCompatibilityScreen), findsOneWidget);
      expect(find.text('Закрыть приложение'), findsOneWidget);
      await tester.tap(find.text('Обновить приложение'));
      await tester.pumpAndSettle();
      expect(find.text('Обновление 1.1.0'), findsOneWidget);
      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
      expect(compatibility.status, CompatibilityStatus.updateRequired);
      expect(service.installerChecks, 0);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Настройки подключения…'));
      await tester.pumpAndSettle();
      expect(find.byType(ServerSettingsDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(ServerSettingsDialog))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Повторить проверку'));
      await tester.pumpAndSettle();
      expect(compatibility.compatible, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
