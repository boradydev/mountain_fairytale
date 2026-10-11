import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/shared/providers/locale_provider.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';
import 'package:mountain_fairytale/features/auth/ui/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_fakes.dart';

void main() {
  testWidgets(
    'selects a username and allows a real login with empty password',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = FakeAuthRepository();
      final service = AuthServiceImpl(
        repository: repository,
        tokenStorage: MemoryTokenStorage(),
      );
      final auth = AuthProvider(authService: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });
      await auth.restoreSession();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
            ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Зарегистрировать'), findsNothing);
      expect(find.byIcon(Icons.fast_forward), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('manager').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(repository.loginCalls, 1);
      expect(repository.lastPassword, '');
      expect(auth.status, AuthStatus.authenticated);
    },
  );
}
