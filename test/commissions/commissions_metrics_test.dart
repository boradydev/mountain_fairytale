import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_metric_help.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_screen.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_summary_panel.dart';

import 'commissions_test.dart' show reportJson, FakeCommissions;

void main() {
  test('employee turnover reads the separate aggregate, not total or personal sums', () {
    final report = CommissionReport.fromJson(reportJson());
    expect(report.employeeTurnover.cents, BigInt.from(7500));
    expect(report.totalTurnover, BigInt.from(15010));
    expect(report.employees.single.turnover.cents, BigInt.from(15010));
  });

  testWidgets('both modes use consistent labels and explanatory hover hints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = CommissionsProvider(FakeCommissions())
      ..month = DateTime(2026, 10);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: CommissionsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Оборот'), findsNothing);
    expect(find.text('Оборотная база'), findsNWidgets(2));
    for (final label in [
      'Общий оборот',
      'Всего к выплате',
      'Представителям',
      'Сотрудникам',
      'Оборот представителей',
    ]) {
      final hint = find.ancestor(
        of: find.text(label),
        matching: find.byType(Tooltip),
      );
      expect(hint, findsOneWidget);
      expect(tester.widget<Tooltip>(hint).message, commissionMetricHelp(label));
      expect(tester.widget<Tooltip>(hint).message, isNot(label));
    }
    await tester.tap(find.text('Сотрудники'));
    await tester.pumpAndSettle();
    expect(find.text('Общая база сотрудников'), findsNothing);
    expect(find.text('Оборот сотрудников'), findsOneWidget);
    expect(find.text('75.00 ₽'), findsOneWidget);
    final hint = find.ancestor(
      of: find.text('Оборот сотрудников'),
      matching: find.byType(Tooltip),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(hint));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.text(commissionMetricHelp('Оборот сотрудников')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [420.0, 900.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('summary fits $width px, $brightness and enlarged text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommissionsSummaryPanel(
                  report: CommissionReport.fromJson(reportJson()),
                  mode: CommissionMode.employees,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Оборот сотрудников'), findsOneWidget);
        expect(find.text('75.00 ₽'), findsOneWidget);
        final hint = find.ancestor(
          of: find.text('Оборот сотрудников'),
          matching: find.byType(Tooltip),
        );
        expect(
          tester.widget<Tooltip>(hint).message,
          commissionMetricHelp('Оборот сотрудников'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
