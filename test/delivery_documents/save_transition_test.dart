import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_provider_test.dart' show Orders, Catalog, Locks, Clients;

class _DelayedCloseOrders extends Orders {
  final closeGate = Completer<void>();
  final finishGate = Completer<void>();
  int closes = 0;
  int finishes = 0;
  _DelayedCloseOrders(Locks locks) : super(Catalog(), locks);

  @override
  Future<bool> closeDocument() async {
    closes++;
    await closeGate.future;
    return super.closeDocument();
  }

  @override
  Future<bool> finishEditingAfterSave() async {
    finishes++;
    await finishGate.future;
    return super.finishEditingAfterSave();
  }
}

class _Session {
  final locks = Locks();
  late final provider = _DelayedCloseOrders(locks);
  final saveGate = Completer<bool>();
  int saves = 0;
  int changes = 0;
  bool? result;

  Future<bool> save() async {
    saves++;
    final creating = provider.documentId == null;
    provider.documentBusy = true;
    provider.notifyListeners();
    try {
      if (!await saveGate.future) {
        provider.documentError = 'Ошибка сохранения';
        return false;
      }
      provider.documentId ??= 'saved-document';
      provider.markDocumentSaved(created: creating);
      return true;
    } finally {
      provider.documentBusy = false;
      provider.notifyListeners();
    }
  }
}

Future<_Session> _open(
  WidgetTester tester,
  String title, {
  bool editing = false,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final theme = ThemeProvider(await SharedPreferences.getInstance());
  final clients = ClientsProvider(Clients());
  final session = _Session();
  addTearDown(theme.dispose);
  addTearDown(clients.dispose);
  addTearDown(session.provider.dispose);
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
              child: const Text('Открыть'),
              onPressed: () async {
                session.result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => DeliveryDocumentEditor(
                      provider: session.provider,
                      title: title,
                      initialize: () async =>
                          session.provider.initializeDocumentSession(
                            id: editing ? 'existing' : null,
                          ),
                      metaBuilder: (_) =>
                          TextFormField(initialValue: 'Данные формы'),
                      save: session.save,
                      changeActive: () async => true,
                      onDocumentChanged: () => session.changes++,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
  if (editing) {
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
  }
  return session;
}

void main() {
  for (final title in ['Самовывоз', 'Маршрутный лист']) {
    for (final editing in [false, true]) {
      testWidgets(
        '$title save ${editing ? 'returns to view after finishing editing' : 'preserves creation through close animation'}',
        (tester) async {
          final session = await _open(tester, title, editing: editing);
          final mode = editing ? 'редактирование' : 'создание';
          await tester.enterText(
            find.byType(TextFormField),
            'Введённые данные',
          );
          final form = tester.state<FormState>(find.byType(Form));
          final originalSave = tester
              .widget<AppPrimaryButton>(
                find.widgetWithText(AppPrimaryButton, 'Сохранить'),
              )
              .onPressed!;
          await tester.tap(find.text('Сохранить'));
          // Even a second callback delivered before a rebuild cannot save twice.
          originalSave();
          await tester.pump();
          expect(session.saves, 1);
          expect(
            tester
                .widget<AppPrimaryButton>(
                  find.widgetWithText(AppPrimaryButton, 'Сохранить'),
                )
                .onPressed,
            isNull,
          );
          session.saveGate.complete(true);
          await tester.pump();
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(find.text('$title ($mode)'), findsOneWidget);
            expect(find.text('$title (просмотр)'), findsNothing);
            expect(find.text('Редактировать'), findsNothing);
            expect(tester.state<FormState>(find.byType(Form)), same(form));
            expect(find.text('Введённые данные'), findsOneWidget);
          }
          expect(session.changes, 1);
          expect(session.provider.documentId, isNotNull);
          if (editing) {
            expect(session.provider.closes, 0);
            session.provider.finishGate.complete();
            await tester.pumpAndSettle();
            expect(find.text('$title (просмотр)'), findsOneWidget);
            expect(find.text('Редактировать'), findsOneWidget);
            expect(session.result, isNull);
            expect(session.locks.released, 1);
            expect(session.provider.finishes, 1);
            await tester.tap(find.text('Редактировать'));
            await tester.pumpAndSettle();
            expect(find.text('$title (редактирование)'), findsOneWidget);
            await tester.tap(find.text('Отмена'));
            await tester.pumpAndSettle();
            expect(find.text('$title (просмотр)'), findsOneWidget);
            session.provider.closeGate.complete();
            await tester.tap(find.text('Закрыть'));
            await tester.pumpAndSettle();
            expect(find.byType(DeliveryDocumentEditor), findsNothing);
            expect(session.result, isTrue);
            expect(session.saves, 1);
            expect(session.locks.released, 2);
            return;
          }
          session.provider.closeGate.complete();
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              find.text('$title (просмотр)', skipOffstage: false),
              findsNothing,
            );
            expect(
              find.text('Редактировать', skipOffstage: false),
              findsNothing,
            );
          }
          await tester.pumpAndSettle();
          expect(find.byType(DeliveryDocumentEditor), findsNothing);
          expect(session.result, isTrue);
          expect(session.saves, 1);
          expect(session.locks.released, editing ? 1 : 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('failed save keeps entered data and allows retry', (
    tester,
  ) async {
    final session = await _open(tester, 'Самовывоз');
    await tester.enterText(find.byType(TextFormField), 'Не терять');
    await tester.tap(find.text('Сохранить'));
    session.saveGate.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Самовывоз (создание)'), findsOneWidget);
    expect(find.text('Не терять'), findsOneWidget);
    expect(find.text('Ошибка сохранения'), findsOneWidget);
    expect(
      tester
          .widget<AppPrimaryButton>(
            find.widgetWithText(AppPrimaryButton, 'Сохранить'),
          )
          .onPressed,
      isNotNull,
    );
    expect(session.provider.documentId, isNull);
    expect(session.provider.closes, 0);
    expect(session.changes, 0);
    expect(tester.takeException(), isNull);
  });

  for (final title in ['Самовывоз', 'Маршрутный лист']) {
    for (final systemBack in [false, true]) {
      testWidgets(
        '$title ${systemBack ? 'system back' : 'appbar back'} cancels edits before closing view',
        (tester) async {
          final session = await _open(tester, title, editing: true);
          await tester.enterText(
            find.byType(TextFormField),
            'Несохранённая правка',
          );
          Future<void> back() async {
            if (systemBack) {
              await tester.binding.handlePopRoute();
            } else {
              await tester.tap(find.byIcon(Icons.arrow_back));
            }
            await tester.pumpAndSettle();
          }

          await back();
          expect(find.text('$title (просмотр)'), findsOneWidget);
          expect(find.text('Несохранённая правка'), findsNothing);
          expect(session.provider.closes, 0);
          expect(session.saves, 0);
          expect(session.locks.released, 1);
          expect(session.result, isNull);
          session.provider.closeGate.complete();
          await back();
          expect(find.byType(DeliveryDocumentEditor), findsNothing);
          expect(session.result, isFalse);
          expect(session.locks.released, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('$title back from a new draft closes without saving', (
      tester,
    ) async {
      final session = await _open(tester, title);
      await tester.enterText(find.byType(TextFormField), 'Новая заготовка');
      session.provider.closeGate.complete();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryDocumentEditor), findsNothing);
      expect(session.provider.documentId, isNull);
      expect(session.saves, 0);
      expect(session.locks.released, 0);
    });
  }

  testWidgets(
    'failed release after save restores real mode and allows closing without another save',
    (tester) async {
      final session = await _open(tester, 'Самовывоз', editing: true);
      session.locks.failRelease = true;
      await tester.tap(find.text('Сохранить'));
      session.saveGate.complete(true);
      session.provider.finishGate.complete();
      session.provider.closeGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Самовывоз (просмотр)'), findsOneWidget);
      expect(
        find.textContaining(
          'Изменения сохранены, но не удалось завершить редактирование',
        ),
        findsOneWidget,
      );
      expect(find.text('Редактировать'), findsOneWidget);
      expect(session.saves, 1);
      expect(session.changes, 1);
      session.locks.failRelease = false;
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryDocumentEditor), findsNothing);
      expect(session.result, isTrue);
      expect(session.saves, 1);
      expect(session.locks.released, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
