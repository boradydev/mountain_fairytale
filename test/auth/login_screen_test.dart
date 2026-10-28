import 'package:flutter/material.dart';

import 'dart:async';

import 'package:mountain_fairytale/features/auth/data/auth_user_model.dart';
import 'package:mountain_fairytale/features/auth/data/auth_tokens_model.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
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
    'password eye preserves input and focus, resets on user change and is disabled during login',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gate = Completer<AuthTokensModel>();
      var failLogin = true;
      final repository = FakeAuthRepository()
        ..users = [
          const AuthUserModel(username: 'manager'),
          const AuthUserModel(username: 'other'),
        ]
        ..onLogin = () {
          if (failLogin) {
            throw const ApiException(statusCode: 401, message: 'Unauthorized');
          }
          return gate.future;
        };
      final service = AuthServiceImpl(
        repository: repository,
        tokenStorage: MemoryTokenStorage(),
      );
      final auth = AuthProvider(authService: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);
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
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('manager').last);
      await tester.pumpAndSettle();
      final password = find.byType(TextField);
      await tester.enterText(password, 'test password');
      final controller = tester.widget<TextField>(password).controller!;
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      await tester.tap(find.byTooltip('Показать пароль'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(password).obscureText, isFalse);
      expect(controller.text, 'test password');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      expect(tester.widget<TextField>(password).focusNode!.hasFocus, isTrue);
      expect(repository.loginCalls, 0);
      final originalPasswordRect = tester.getRect(password);
      final originalButtonRect = tester.getRect(
        find.widgetWithText(FilledButton, 'Войти'),
      );
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Неверный пароль.'), findsOneWidget);
      expect(tester.getRect(password), originalPasswordRect);
      expect(
        tester.getRect(find.widgetWithText(FilledButton, 'Войти')),
        originalButtonRect,
      );
      await tester.enterText(password, 'corrected password');
      await tester.pumpAndSettle();
      expect(find.text('Неверный пароль.'), findsNothing);
      expect(tester.getRect(password), originalPasswordRect);
      failLogin = false;
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('other').last);
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      await tester.enterText(password, 'submitted');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester.getRect(find.widgetWithText(FilledButton, 'Войти')),
        originalButtonRect,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.visibility_outlined),
            )
            .onPressed,
        isNull,
      );
      expect(repository.lastPassword, 'submitted');
      gate.complete(originalTokens);
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(tester.widget<TextField>(password).obscureText, isTrue);
    },
  );

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
