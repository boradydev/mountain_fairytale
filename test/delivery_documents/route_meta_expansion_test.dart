import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_selection_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';

import 'document_provider_test.dart' show Orders, Catalog, Locks, Clients;

void main() {
  testWidgets(
    'trip panel preserves input and expansion across document modes and reveals validation errors',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final provider = Orders(Catalog(), Locks());
      final clients = ClientsProvider(Clients());
      final theme = ThemeProvider(await SharedPreferences.getInstance());
      addTearDown(provider.dispose);
      addTearDown(clients.dispose);
      addTearDown(theme.dispose);
      var draft = 'Сохранённое значение';
      var saves = 0;

      Widget app(Key editorKey) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: clients),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: MaterialApp(
          home: DeliveryDocumentEditor(
            key: editorKey,
            provider: provider,
            title: 'Маршрутный лист',
            initialize: () async => provider.initializeDocumentSession(),
            metaBuilder: (_) => Column(
              children: [
                TextFormField(
                  enabled: provider.canEdit,
                  initialValue: draft,
                  decoration: const InputDecoration(
                    labelText: 'Данные рейса для проверки',
                  ),
                  onChanged: (value) => draft = value,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Заполните поле рейса'
                      : null,
                ),
                const SizedBox(height: 200),
              ],
            ),
            save: () async {
              saves++;
              return true;
            },
            changeActive: () async => true,
          ),
        ),
      );

      final header = find.text('1. Данные рейса');
      await tester.pumpWidget(app(const ValueKey('first-open')));
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField);
      expect(field, findsOneWidget);
      final expandedClientHeight = tester
          .getSize(find.byType(ClientSelectionPanel))
          .height;
      await tester.enterText(field, 'Введённое значение');
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(
        tester.getSize(find.byType(ClientSelectionPanel)).height,
        greaterThan(expandedClientHeight),
      );
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        'Введённое значение',
      );
      await tester.enterText(field, '');
      await tester.tap(header);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Заполните поле рейса'), findsOneWidget);
      expect(saves, 0);
      await tester.enterText(field, 'Исправленное значение');
      await tester.tap(header);
      await tester.pumpAndSettle();

      provider.initializeDocumentSession(id: 'document');
      provider.notifyListeners();
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).enabled, isFalse);
      await tester.tap(header);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).enabled, isTrue);
      await tester.tap(header);
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(const ValueKey('second-open')));
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
