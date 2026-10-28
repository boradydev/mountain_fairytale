import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mountain_fairytale/core/network/client_build_info.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_provider.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_screen.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/auth/ui/login_screen.dart';
import 'package:mountain_fairytale/main.dart';
import 'package:mountain_fairytale/shared/providers/locale_provider.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';

import '../auth/auth_fakes.dart';

const supported = HttpTransportResponse(
  statusCode: 200,
  body: '{"data":{"backendVersion":"1.0.0","minClientVersion":"1.1.0"}}',
);

class ConnectionTransport extends HttpTransport {
  ConnectionTransport() : super(baseUrl: 'http://test');
  Future<HttpTransportResponse> Function() respond = () async => supported;

  @override
  Future<HttpTransportResponse> get(
    String path, {
    Map<String, String>? headers,
  }) => respond();
}

void main() {
  late ConnectionTransport transport;
  late AppCompatibilityProvider compatibility;
  late MemoryTokenStorage storage;
  late FakeAuthRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          (_) async => null,
        );
    transport = ConnectionTransport();
    compatibility = AppCompatibilityProvider(
      transport: transport,
      loadBuild: () async => ClientBuildInfo(version: '1.1.0', build: '1'),
    );
    storage = MemoryTokenStorage();
    repository = FakeAuthRepository();
  });

  tearDown(() {
    compatibility.dispose();
    transport.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  Future<void> showApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthServiceImpl(repository: repository, tokenStorage: storage);
    final authProvider = AuthProvider(authService: auth);
    final theme = ThemeProvider(prefs);
    final locale = LocaleProvider(prefs);
    addTearDown(() {
      authProvider.dispose();
      auth.dispose();
      theme.dispose();
      locale.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: compatibility),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: const MyApp(sessionProviders: []),
      ),
    );
  }

  testWidgets(
    'offline startup stays on login and retry recovers without restart',
    (tester) async {
      transport.respond = () async => throw const SocketException('offline');
      await compatibility.check();
      await showApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppCompatibilityScreen), findsNothing);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('Сервер недоступен'), findsOneWidget);
      expect(find.text('Требуется обновление'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      transport.respond = () async => supported;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(compatibility.compatible, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('manager'), findsOneWidget);
      await tester.tap(find.text('manager'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('startup check shows progress inside login', (tester) async {
    final pending = Completer<HttpTransportResponse>();
    transport.respond = () => pending.future;
    final check = compatibility.check();
    await showApp(tester);
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Подключение к серверу…'), findsOneWidget);
    expect(find.byType(AppCompatibilityScreen), findsNothing);
    pending.complete(supported);
    await check;
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful retry that confirms incompatibility replaces login', (
    tester,
  ) async {
    transport.respond = () async => throw const SocketException('offline');
    await compatibility.check();
    await showApp(tester);
    await tester.pumpAndSettle();
    transport.respond = () async => const HttpTransportResponse(
      statusCode: 200,
      body: '{"data":{"backendVersion":"1.0.0","minClientVersion":"1.2.0"}}',
    );
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Требуется обновление'), findsOneWidget);
    expect(find.byType(AppCompatibilityScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'unavailable session restore displays login and preserves saved token',
    (tester) async {
      await compatibility.check();
      storage.refresh = 'saved-refresh';
      repository.onRefresh = (_) async =>
          throw const SocketException('offline');
      await showApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('Сервер недоступен'), findsOneWidget);
      expect(find.byType(AppCompatibilityScreen), findsNothing);
      expect(storage.refresh, 'saved-refresh');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'temporary outage on recheck preserves open form and compatibility',
    (tester) async {
      await compatibility.check();
      await showApp(tester);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(LoginScreen));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Открытая форма'),
          content: TextField(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'черновик');
      transport.respond = () async =>
          const HttpTransportResponse(statusCode: 503, body: '{}');
      await compatibility.check();
      await tester.pumpAndSettle();
      expect(compatibility.compatible, isTrue);
      expect(compatibility.workEpoch, 0);
      expect(find.text('Открытая форма'), findsOneWidget);
      expect(find.text('черновик'), findsOneWidget);
      expect(find.byType(AppCompatibilityScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
