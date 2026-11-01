import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/shared/utils/app_date_range_picker.dart';
import 'package:mountain_fairytale/shared/widgets/app_date_range_dialog.dart';

Future<void> _open(
  WidgetTester tester, {
  required ValueChanged<DateTimeRange?> result,
  bool fixedToday = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final initial = DateTimeRange(
                start: DateTime(2026, 11, 1),
                end: DateTime(2026, 11, 2),
              );
              result(
                await (fixedToday
                    ? showDialog<DateTimeRange>(
                        context: context,
                        builder: (_) => AppDateRangeDialog(
                          title: 'Период продаж',
                          initialDateRange: initial,
                          currentDate: DateTime(2026, 1, 15),
                        ),
                      )
                    : showAppDateRangePicker(
                        context,
                        initialDateRange: initial,
                        helpText: 'Период продаж',
                      )),
              );
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

Finder get _from => find.byKey(const ValueKey('period-start'));
Finder get _to => find.byKey(const ValueKey('period-end'));

void main() {
  testWidgets('manual multi-year range is applied only on confirmation', (
    tester,
  ) async {
    DateTimeRange? result;
    await _open(tester, result: (value) => result = value);
    expect(tester.widget<TextFormField>(_from).controller!.text, '01.11.2026');
    await tester.enterText(_from, '01.01.1998');
    await tester.enterText(_to, '31.12.2026');
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(result!.start, DateTime(1998));
    expect(result!.end, DateTime(2026, 12, 31));
    expect(find.byType(AppDateRangeDialog), findsNothing);
  });

  testWidgets(
    'invalid dates and reversed range stay in the dialog with field errors',
    (tester) async {
      DateTimeRange? result;
      await _open(tester, result: (value) => result = value);
      await tester.enterText(_from, '31.02.2026');
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(find.text('Введите дату дд.мм.гггг'), findsOneWidget);
      await tester.enterText(_from, '10.11.2026');
      await tester.enterText(_to, '09.11.2026');
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(find.text('Окончание раньше начала'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(_to, '10.11.2026');
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(result!.duration, Duration.zero);
    },
  );

  testWidgets(
    'calendar chooses a range in either direction and synchronizes fields',
    (tester) async {
      DateTimeRange? result;
      await _open(tester, result: (value) => result = value);
      await tester.ensureVisible(
        find.byKey(const ValueKey('period-day-2026-11-10')),
      );
      await tester.tap(find.byKey(const ValueKey('period-day-2026-11-10')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(_to).controller!.text, isEmpty);
      await tester.tap(find.byKey(const ValueKey('period-day-2026-11-04')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_from).controller!.text,
        '04.11.2026',
      );
      expect(tester.widget<TextFormField>(_to).controller!.text, '10.11.2026');
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(
        result,
        DateTimeRange(
          start: DateTime(2026, 11, 4),
          end: DateTime(2026, 11, 10),
        ),
      );
    },
  );

  testWidgets(
    'preset handles the previous year and cancellation applies nothing',
    (tester) async {
      DateTimeRange? result;
      var closed = false;
      await _open(
        tester,
        fixedToday: true,
        result: (value) {
          result = value;
          closed = true;
        },
      );
      await tester.tap(find.text('Прошлый месяц'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_from).controller!.text,
        '01.12.2025',
      );
      expect(tester.widget<TextFormField>(_to).controller!.text, '31.12.2025');
      expect(closed, isFalse);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    },
  );

  testWidgets(
    'calendar selection spans months without applying until confirmed',
    (tester) async {
      DateTimeRange? result;
      await _open(tester, result: (value) => result = value);
      final firstDay = find.byKey(const ValueKey('period-day-2026-11-28'));
      await tester.ensureVisible(firstDay);
      await tester.tap(firstDay);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Следующий месяц'));
      await tester.tap(find.byTooltip('Следующий месяц'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('period-day-2026-12-03')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_from).controller!.text,
        '28.11.2026',
      );
      expect(tester.widget<TextFormField>(_to).controller!.text, '03.12.2026');
      expect(result, isNull);
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(result!.duration.inDays, 5);
    },
  );

  testWidgets(
    'out-of-bounds date is rejected and Enter confirms corrected input',
    (tester) async {
      DateTimeRange? result;
      await _open(tester, result: (value) => result = value);
      await tester.enterText(_from, '01.01.1899');
      await tester.enterText(_to, '01.01.1901');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text('Дата должна быть в пределах 1900–2100'),
        findsOneWidget,
      );
      expect(result, isNull);
      await tester.enterText(_from, '01.01.1900');
      await tester.enterText(_to, '01.01.1901');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result!.start, DateTime(1900));
    },
  );

  testWidgets('small window scrolls content and keeps confirmation visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 580);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DateTimeRange? result;
    await _open(tester, result: (value) => result = value);
    expect(tester.takeException(), isNull);
    expect(find.text('Подтвердить').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(result!.start, DateTime(2026, 11, 1));
  });
}
