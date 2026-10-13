import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';

import 'document_provider_test.dart' show Orders, Catalog, Locks, Clients;

void main() {
  testWidgets('view/edit/lost lock/close obey lifecycle without autosave', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final locks = Locks();
    final provider = Orders(Catalog(), locks);
    final clients = ClientsProvider(Clients());
    final theme = ThemeProvider(prefs);
    addTearDown(provider.dispose);
    addTearDown(clients.dispose);
    addTearDown(theme.dispose);
    var saves = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: clients),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Открыть документ'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeliveryDocumentEditor(
                      provider: provider,
                      title: 'Самовывоз',
                      initialize: () async =>
                          provider.initializeDocumentSession(id: 'document'),
                      metaBuilder: (_) => const SizedBox(height: 80),
                      save: () async {
                        saves++;
                        return true;
                      },
                      changeActive: () async => true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть документ'));
    await tester.pumpAndSettle();
    expect(locks.acquired, 0);
    expect(find.text('Начать редактирование'), findsOneWidget);
    expect(find.text('Сохранить'), findsNothing);
    await tester.tap(find.text('Начать редактирование'));
    await tester.pumpAndSettle();
    expect(locks.acquired, 1);
    expect(find.text('Сохранить'), findsOneWidget);
    locks.failRenew = true;
    await provider.renewDocumentLock();
    await tester.pumpAndSettle();
    expect(find.text('Сохранить'), findsNothing);
    expect(find.textContaining('Блокировка потеряна'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Открыть документ'), findsOneWidget);
    expect(locks.released, 1);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });
}
