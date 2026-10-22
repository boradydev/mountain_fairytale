import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/app_updates/data/update_release.dart';
import 'package:mountain_fairytale/features/app_updates/update_service.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_button.dart';

class FakeUpdates extends UpdateService {
  int installerChecks = 0;
  int feedChecks = 0;
  @override
  Future<UpdateRelease?> latest() async {
    feedChecks++;
    return const UpdateRelease(
      version: '1.1.0',
      buildNumber: 20,
      description: 'Исправлены ошибки',
    );
  }

  @override
  Future<void> checkWithUi() async {
    installerChecks++;
  }
}

void main() {
  testWidgets('passive check never starts an installer; user can defer', (
    tester,
  ) async {
    final service = FakeUpdates();
    final updates = UpdateProvider(service)
      ..ready = true
      ..installedVersion = '1.0.0+1';
    addTearDown(updates.dispose);
    await updates.check();
    expect(service.installerChecks, 0);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: updates,
        child: const MaterialApp(
          home: Scaffold(appBar: null, body: UpdateButton()),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Обновление 1.1.0'), findsOneWidget);
    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();
    expect(service.installerChecks, 0);
  });

  testWidgets('open editor prevents any update action', (tester) async {
    final service = FakeUpdates();
    final updates = UpdateProvider(service)..ready = true;
    addTearDown(updates.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: updates,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Основной экран')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: UpdateButton()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(service.feedChecks, 0);
    expect(service.installerChecks, 0);
  });

  testWidgets(
    'confirmed update blocks edits until native updater is dismissed',
    (tester) async {
      final service = FakeUpdates();
      final updates = UpdateProvider(service)
        ..ready = true
        ..installedVersion = '1.0.0+1';
      addTearDown(updates.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: updates,
          child: const MaterialApp(home: Scaffold(body: UpdateButton())),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(service.installerChecks, 1);
      expect(find.text('Обновление приложения'), findsOneWidget);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        'mountain_fairytale/updates',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('dismissed'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text('Обновление приложения'), findsNothing);
      addTearDown(() => UpdateService.channel.setMethodCallHandler(null));
    },
  );
}
