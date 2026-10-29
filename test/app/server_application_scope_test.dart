import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/app/server_application_scope.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fakes.dart';

class _AuthService extends AuthServiceImpl {
  bool disposed = false;

  _AuthService(MemoryTokenStorage storage)
    : super(repository: FakeAuthRepository(), tokenStorage: storage);

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  testWidgets(
    'rebuilds retain the authenticated API session; server change replaces it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = ServerSettingsProvider(
        ServerSettingsRepository(
          await SharedPreferences.getInstance(),
          defaultUrl: 'http://first:8000',
        ),
      );
      final rebuild = ValueNotifier(0);
      final storage = MemoryTokenStorage()
        ..refresh = originalTokens.refreshToken;
      final transport = RecordingTransport()
        ..respond = (_) async => envelope([]);
      final services = <_AuthService>[];
      addTearDown(settings.dispose);
      addTearDown(rebuild.dispose);
      addTearDown(transport.close);

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: Listenable.merge([settings, rebuild]),
          builder: (_, _) => ServerApplicationScope(
            key: ValueKey(settings.url),
            createApplication: () {
              final service = _AuthService(storage);
              services.add(service);
              return MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthServiceImpl>(
                    lazy: false,
                    create: (_) => service,
                  ),
                  ListenableProvider<AuthService>.value(value: service),
                  ChangeNotifierProvider(
                    create: (_) => AuthProvider(authService: service),
                  ),
                  Provider<ApiClient>.value(
                    value: ApiClient(
                      transport: transport,
                      authService: service,
                    ),
                  ),
                ],
                child: const SizedBox(key: ValueKey('application')),
              );
            },
          ),
        ),
      );

      BuildContext applicationContext() =>
          tester.element(find.byKey(const ValueKey('application')));
      final auth = applicationContext().read<AuthProvider>();
      await auth.restoreSession();
      expect(auth.isAuthenticated, isTrue);

      // This repeated builder invocation used to create an unauthenticated
      // ApiClient while AuthProvider retained the original authenticated service.
      rebuild.value++;
      await tester.pump();
      final reassembly = tester.binding.reassembleApplication();
      await tester.pump();
      await reassembly;
      expect(services, hasLength(1));
      expect(applicationContext().read<AuthProvider>(), same(auth));
      expect(applicationContext().read<AuthService>(), same(services.single));
      expect(
        await applicationContext().read<ApiClient>().getList(
          '/protected/clients',
        ),
        isEmpty,
      );
      expect(
        transport.requests.last.headers?['Authorization'],
        'Bearer ${renewedTokens.accessToken}',
      );

      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(await auth.login(username: 'manager', password: ''), isTrue);
      await applicationContext().read<ApiClient>().getList(
        '/protected/clients',
      );
      expect(services, hasLength(1));

      await settings.changeUrl('http://second:8000', endSession: auth.logout);
      await tester.pump();
      expect(services, hasLength(2));
      expect(services.first.disposed, isTrue);
      expect(storage.refresh, isNull);
      final nextAuth = applicationContext().read<AuthProvider>();
      expect(nextAuth, isNot(same(auth)));
      expect(nextAuth.currentUser, isNull);
      expect(applicationContext().read<AuthService>(), same(services.last));
      expect(await nextAuth.login(username: 'manager', password: ''), isTrue);
      await applicationContext().read<ApiClient>().getList(
        '/protected/clients',
      );

      await tester.pumpWidget(const SizedBox());
      expect(services.last.disposed, isTrue);
    },
  );
}
