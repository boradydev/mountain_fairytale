import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/shared/widgets/app_notify.dart';
import 'package:mountain_fairytale/shared/widgets/snack_bar_widget.dart';

Widget notificationApp({
  required Widget home,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.createTheme(brightness).copyWith(
    textTheme: AppTheme.createTheme(brightness).textTheme.apply(
      fontFamily: 'NotificationPreview',
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
    ),
    child: AppNotificationHost(child: child!),
  ),
  home: home,
);

void main() {
  setUpAll(() async {
    final font = FontLoader('NotificationPreview')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets(
    'latest message replaces the previous one and resets its lifetime',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(notificationApp(home: const Scaffold()));
      AppNotify.show('Сохранено');
      await tester.pump();
      expect(find.text('Сохранено'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 2));
      AppNotify.show('Повторите запрос', isError: true);
      await tester.pump();
      expect(find.text('Сохранено'), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('Повторите запрос'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppSnackBarContent), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'notification paints above nested modal routes and passes clicks through',
    (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      var clicks = 0;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: notificationApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => Dialog.fullscreen(
                      child: Center(
                        child: TextButton(
                          onPressed: () => showDialog<void>(
                            context: dialogContext,
                            builder: (_) => Dialog.fullscreen(
                              backgroundColor: Colors.purple,
                              child: Stack(
                                children: [
                                  Center(
                                    child: TextButton(
                                      onPressed: () => AppNotify.show(
                                        'Пароль сотрудника изменён.',
                                      ),
                                      child: const Text('Показать уведомление'),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    height: 120,
                                    child: TextButton(
                                      onPressed: () => clicks++,
                                      child: const Text(
                                        'Кнопка под уведомлением',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: const Text('Вложенный диалог'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Открыть'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вложенный диалог'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Показать уведомление'));
      await tester.pumpAndSettle();
      final card = find.byType(AppSnackBarContent);
      expect(card, findsOneWidget);
      final rect = tester.getRect(card);
      final color = Theme.of(tester.element(card))
          .colorScheme
          .surfaceContainerHigh;

      // Assert actual painted pixels, rather than finding text hidden by a dialog.
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final point = rect.centerLeft + const Offset(8, 0);
        final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        expect(pixels.getUint8(index), (color.r * 255).round());
        expect(pixels.getUint8(index + 1), (color.g * 255).round());
        expect(pixels.getUint8(index + 2), (color.b * 255).round());
        image.dispose();
      });

      await tester.tapAt(rect.center);
      await tester.pump();
      expect(clicks, 1);
      expect(find.text('Показать уведомление'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'disposing the host cancels timers and does not leak a message into a new host',
    (
      tester,
    ) async {
      await tester.pumpWidget(notificationApp(home: const Scaffold()));
      AppNotify.show('Старый сервер');
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      AppNotify.show('Нет активного приложения');
      await tester.pumpWidget(notificationApp(home: const Scaffold()));
      expect(find.byType(AppSnackBarContent), findsNothing);
      AppNotify.show('Новый сервер', isWarning: true);
      await tester.pump();
      expect(find.text('Новый сервер'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(AppSnackBarContent), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    for (final compact in [false, true]) {
      testWidgets('long notification fits ${brightness.name}; compact=$compact', (
        tester,
      ) async {
        final size = compact ? const Size(400, 600) : const Size(1000, 700);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: notificationApp(
              brightness: brightness,
              textScale: compact ? 2 : 1,
              home: const Scaffold(body: Center(child: Text('Приложение'))),
            ),
          ),
        );
        AppNotify.show(
          'Адрес не изменён. Не удалось очистить сохранённый вход или записать настройки. Повторите попытку.',
          isError: true,
        );
        await tester.pump();
        final rect = tester.getRect(find.byType(AppSnackBarContent));
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(size.width - 16));
        expect(rect.top, greaterThanOrEqualTo(16));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 16));
        expect(tester.takeException(), isNull);

        if (Platform.environment['SAVE_NOTIFICATION_PREVIEWS'] == '1') {
          await tester.runAsync(() async {
            final directory = Directory('tmp/operations/notification-previews');
            await directory.create(recursive: true);
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '${directory.path}/${brightness.name}-${compact ? 'compact' : 'desktop'}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
