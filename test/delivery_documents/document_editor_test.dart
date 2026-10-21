import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/document_mode_banner.dart';
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
    expect(find.text('Самовывоз (просмотр)'), findsOneWidget);
    expect(find.text('Только просмотр'), findsOneWidget);
    expect(
      find.text('Чтобы изменить документ, начните редактирование.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Просмотр. Начните редактирование'),
      findsNothing,
    );
    expect(locks.acquired, 0);
    expect(find.text('Редактировать'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DocumentModeBanner),
        matching: find.text('Редактировать'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithIcon(TextField, Icons.search))
          .enabled,
      isFalse,
    );
    expect(find.text('Сохранить'), findsNothing);
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    expect(find.text('Самовывоз (редактирование)'), findsOneWidget);
    expect(find.text('Редактирование'), findsOneWidget);
    expect(find.text('Только просмотр'), findsNothing);
    expect(locks.acquired, 1);
    expect(
      tester
          .widget<TextField>(find.widgetWithIcon(TextField, Icons.search))
          .enabled,
      isTrue,
    );
    expect(find.text('Сохранить'), findsOneWidget);
    locks.failRenew = true;
    await provider.renewDocumentLock();
    await tester.pumpAndSettle();
    expect(find.text('Сохранить'), findsNothing);
    expect(find.textContaining('Блокировка потеряна'), findsOneWidget);
    expect(find.text('Только просмотр'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithIcon(TextField, Icons.search))
          .enabled,
      isFalse,
    );
    provider.documentActive = false;
    provider.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Редактировать'), findsNothing);
    expect(
      find.text('Документ отменён. Для редактирования восстановите его.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Открыть документ'), findsOneWidget);
    expect(locks.released, 1);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cancel returns to view and preserves action positions for a second click to close',
    (tester) async {
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
      var activeChanges = 0;
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
                        title: 'Маршрутный лист',
                        initialize: () async =>
                            provider.initializeDocumentSession(),
                        metaBuilder: (_) =>
                            TextFormField(initialValue: 'Сохранённое значение'),
                        save: () async {
                          saves++;
                          return true;
                        },
                        changeActive: () async {
                          activeChanges++;
                          return true;
                        },
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
      expect(find.text('Маршрутный лист (создание)'), findsOneWidget);
      expect(find.text('Новый маршрутный лист'), findsOneWidget);
      final bannerRect = tester.getRect(find.byType(DocumentModeBanner));
      final creationCloseRect = tester.getRect(
        find.widgetWithText(AppSecondaryButton, 'Закрыть'),
      );
      final creationSaveRect = tester.getRect(
        find.widgetWithText(AppPrimaryButton, 'Сохранить'),
      );
      provider.initializeDocumentSession(id: 'document');
      provider.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Маршрутный лист (просмотр)'), findsOneWidget);
      final close = find.widgetWithText(AppSecondaryButton, 'Закрыть');
      final edit = find.widgetWithText(
        AppPrimaryButton,
        'Редактировать',
      );
      final closeRect = tester.getRect(close);
      final editRect = tester.getRect(edit);
      expect(closeRect, creationCloseRect);
      expect(tester.getRect(find.byType(DocumentModeBanner)), bannerRect);
      expect(editRect.bottom, lessThanOrEqualTo(bannerRect.bottom));
      final cancelDocumentRect = tester.getRect(
        find.widgetWithText(AppSecondaryButton, 'Отменить документ'),
      );
      expect(closeRect.center.dx, lessThan(editRect.center.dx));
      expect(closeRect.center.dx, lessThan(cancelDocumentRect.center.dx));
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Маршрутный лист (редактирование)'), findsOneWidget);
      expect(tester.getRect(find.byType(DocumentModeBanner)), bannerRect);
      expect(find.text('Закрыть'), findsNothing);
      expect(find.text('Отменить документ'), findsNothing);
      expect(
        tester.getRect(find.widgetWithText(AppSecondaryButton, 'Отмена')),
        closeRect,
      );
      expect(
        tester.getRect(find.widgetWithText(AppPrimaryButton, 'Сохранить')),
        creationSaveRect,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Несохранённое изменение',
      );
      await tester.tapAt(closeRect.center);
      await tester.pumpAndSettle();
      expect(find.text('Маршрутный лист (просмотр)'), findsOneWidget);
      expect(find.text('Несохранённое изменение'), findsNothing);
      expect(find.text('Сохранённое значение'), findsOneWidget);
      expect(tester.getRect(close), closeRect);
      expect(tester.getRect(edit), editRect);
      expect(provider.isEditing, isFalse);
      expect(locks.released, 1);
      expect(saves, 0);
      expect(activeChanges, 0);
      await tester.tapAt(closeRect.center);
      await tester.pumpAndSettle();
      expect(find.text('Открыть документ'), findsOneWidget);
      expect(locks.released, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
