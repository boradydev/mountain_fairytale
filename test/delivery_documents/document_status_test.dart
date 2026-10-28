import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/document_mode_banner.dart';
import 'package:mountain_fairytale/shared/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_provider_test.dart'
    show Orders, Catalog, Locks, Clients, point;

void main() {
  for (final brightness in Brightness.values) {
    for (final title in ['Самовывоз', 'Маршрутный лист']) {
      testWidgets(
        '$title status and lock messages keep form in place in $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final theme = ThemeProvider(await SharedPreferences.getInstance());
          final clients = ClientsProvider(Clients());
          final locks = Locks();
          final orders = Orders(Catalog(), locks);
          addTearDown(theme.dispose);
          addTearDown(clients.dispose);
          addTearDown(orders.dispose);
          var requests = 0;
          var changes = 0;
          var failChange = false;
          const metaKey = ValueKey('meta');
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: theme),
                ChangeNotifierProvider.value(value: clients),
              ],
              child: MaterialApp(
                theme: AppTheme.createTheme(brightness),
                home: DeliveryDocumentEditor(
                  provider: orders,
                  title: title,
                  initialize: () async {
                    orders.initializeDocumentSession(id: 'document');
                    orders.points = [point];
                  },
                  metaBuilder: (_) => const SizedBox(key: metaKey, height: 80),
                  save: () async => false,
                  changeActive: () async {
                    requests++;
                    if (failChange) {
                      orders.documentError = 'Не удалось выполнить запрос.';
                      orders.notifyListeners();
                      return false;
                    }
                    orders.documentActive = !orders.documentActive;
                    orders.documentError = null;
                    orders.notifyListeners();
                    return true;
                  },
                  onDocumentChanged: () => changes++,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final originalMeta = tester.getRect(find.byKey(metaKey));
          final banner = find.byType(DocumentModeBanner);
          final originalBanner = tester.getRect(banner);
          final originalColor =
              tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: banner,
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          locks.acquireError = const ApiException(
            statusCode: 423,
            message: 'Locked',
            ownerName: 'rehearsal_admin',
          );
          await tester.tap(find.text('Редактировать'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: banner,
              matching: find.textContaining('rehearsal_admin'),
            ),
            findsOneWidget,
          );
          expect(tester.getRect(find.byKey(metaKey)), originalMeta);
          expect(tester.getRect(banner), originalBanner);
          expect(orders.isEditing, isFalse);
          expect(orders.editingBlockedBy, 'rehearsal_admin');
          final blockedTitle = find.text(
            'Документ редактирует другой сотрудник',
          );
          expect(blockedTitle, findsOneWidget);
          expect(find.byIcon(Icons.lock_outline), findsOneWidget);
          final blockedDecoration =
              tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: banner,
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          expect(
            blockedDecoration.color,
            AppTheme.createTheme(brightness)
                .extension<AppColorsExtension>()!
                .warningContainer,
          );
          expect(
            tester.widget<Text>(blockedTitle).style!.fontSize,
            greaterThan(14),
          );
          final liveRegion = find.descendant(
            of: banner,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.liveRegion == true,
            ),
          );
          expect(
            tester.getCenter(blockedTitle).dx,
            tester.getCenter(liveRegion).dx,
          );
          // A generic connection error must not inherit the foreign-owner state.
          locks.acquireError = StateError('offline');
          await tester.tap(find.text('Редактировать'));
          await tester.pumpAndSettle();
          expect(orders.editingBlockedBy, isNull);
          expect(find.byIcon(Icons.lock_outline), findsNothing);
          expect(find.text('Только просмотр'), findsOneWidget);
          locks.acquireError = null;
          await tester.tap(find.text('Редактировать'));
          await tester.pumpAndSettle();
          expect(find.textContaining('rehearsal_admin'), findsNothing);
          await tester.tap(find.text('Отмена'));
          await tester.pumpAndSettle();
          // Cancelling the confirmation must not change the document.
          await tester.tap(find.text('Отменить документ'));
          await tester.pumpAndSettle();
          expect(find.textContaining('менеджеров офиса'), findsOneWidget);
          expect(
            find.textContaining('Несохранённые изменения формы'),
            findsNothing,
          );
          await tester.tap(find.text('Отмена'));
          await tester.pumpAndSettle();
          expect(requests, 0);
          await tester.tap(find.text('Отменить документ'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Отменить документ').last);
          await tester.pumpAndSettle();
          expect(find.text('Документ отменён'), findsOneWidget);
          expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
          expect(find.text('Редактировать'), findsNothing);
          expect(orders.points, [point]);
          expect(changes, 1);
          expect(tester.getRect(find.byKey(metaKey)), originalMeta);
          final cancelledColor =
              tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: banner,
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          expect(cancelledColor.color, isNot(originalColor.color));
          final warning = AppTheme.createTheme(brightness)
              .extension<AppColorsExtension>()!;
          expect(cancelledColor.color, warning.warningContainer);
          expect(
            tester.widget<Icon>(find.byIcon(Icons.archive_outlined)).color,
            warning.warningColor,
          );
          final textColor = tester
              .widget<Text>(find.text('Документ отменён'))
              .style!
              .color!;
          final textLuminance = textColor.computeLuminance();
          final backgroundLuminance = cancelledColor.color!.computeLuminance();
          final contrast = textLuminance > backgroundLuminance
              ? (textLuminance + 0.05) / (backgroundLuminance + 0.05)
              : (backgroundLuminance + 0.05) / (textLuminance + 0.05);
          expect(contrast, greaterThanOrEqualTo(4.5));
          await tester.tap(find.text('Восстановить'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Сохранённые начисления'), findsOneWidget);
          failChange = true;
          await tester.tap(find.text('Восстановить').last);
          await tester.pumpAndSettle();
          expect(find.text('Документ отменён'), findsOneWidget);
          expect(changes, 1);
          expect(tester.getRect(find.byKey(metaKey)), originalMeta);
          failChange = false;
          await tester.tap(find.text('Восстановить'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Восстановить').last);
          await tester.pumpAndSettle();
          expect(find.text('Только просмотр'), findsOneWidget);
          expect(find.text('Редактировать'), findsOneWidget);
          expect(find.text('Документ отменён'), findsNothing);
          expect(orders.points, [point]);
          expect(changes, 2);
          expect(tester.getRect(find.byKey(metaKey)), originalMeta);
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final width in [420.0, 900.0]) {
      testWidgets(
        'banner preserves size with long message at $width in $brightness',
        (tester) async {
          tester.view.physicalSize = Size(width, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var message = '';
          late StateSetter update;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Column(
                      children: [
                        DocumentModeBanner(
                          creating: false,
                          editing: false,
                          active: true,
                          creationTitle: 'Новый документ',
                          message: message.isEmpty ? null : message,
                          editingBlockedBy: message.isEmpty ? null : message,
                          onEdit: () {},
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          final rect = tester.getRect(find.byType(DocumentModeBanner));
          update(
            () => message = 'Документ редактирует сотрудник с очень длинным именем и фамилией. Повторите попытку после завершения его работы.',
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byType(DocumentModeBanner)), rect);
          final tooltip = find.byTooltip(message);
          expect(tooltip, findsOneWidget);
          await tester.longPress(tooltip);
          await tester.pumpAndSettle();
          expect(find.text(message), findsNWidgets(2));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
