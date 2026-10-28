import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/core/theme.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_screen.dart';
import 'package:mountain_fairytale/features/commissions/ui/representative_commission_dialog.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

import 'commissions_test.dart'
    show FakeCommissions, reportJson, detailsJson, representative;

class ManagedReport extends FakeCommissions {
  bool active = false;
  bool empty = false;
  String? createdName;
  @override
  Future<CommissionReport> report(
    DateTime month, {
    required bool includeDeactivated,
  }) async {
    calls.add((month, includeDeactivated));
    return CommissionReport.fromJson({
      ...reportJson(),
      'salesRepresentatives': [
        if (!empty) {...representative(), 'isActive': active},
        if (createdName != null)
          {
            ...representative(id: 'created'),
            'salesRepresentativeName': createdName,
          },
      ],
    });
  }

  @override
  Future<RepresentativeCommissionDetails> details(
    String id,
    DateTime month,
  ) async => RepresentativeCommissionDetails.fromJson({
    ...detailsJson(assigned),
    'isActive': active,
  });
}

class ManagedRepresentatives implements SalesRepresentativeApiRepository {
  final ManagedReport report;
  ManagedRepresentatives(this.report);
  bool fail = false;
  Completer<void>? gate;
  final patches = <Map<String, dynamic>>[];
  int creates = 0;
  ApiSalesRepresentative row(String id, String name, bool active) =>
      ApiSalesRepresentative(
        id: id,
        name: name,
        phone: '+79123456789',
        commissionPercent: 5,
        isActive: active,
      );
  @override
  Future<ApiSalesRepresentative> update(
    String id,
    Map<String, dynamic> changes,
  ) async {
    patches.add(changes);
    if (fail) throw StateError('offline');
    if (gate != null) await gate!.future;
    report.active = changes['isActive'] as bool;
    return row(id, 'Уволенный представитель', report.active);
  }

  @override
  Future<ApiSalesRepresentative?> checkDuplicate(
    String name,
    String phone,
  ) async => null;
  @override
  Future<ApiSalesRepresentative> create({
    required String name,
    required String phone,
    required double commissionPercent,
  }) async {
    creates++;
    report.createdName = name;
    return row('created', name, true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<CommissionsProvider> openScreen(
  WidgetTester tester,
  ManagedReport report,
  ManagedRepresentatives reps, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = CommissionsProvider(report)..month = DateTime(2026, 10);
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        Provider<SalesRepresentativeApiRepository>.value(value: reps),
      ],
      child: MaterialApp(
        theme: AppTheme.createTheme(brightness),
        home: const Scaffold(body: CommissionsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'representative activity preserves historical amounts and assignments in $brightness',
      (tester) async {
        final report = ManagedReport();
        final reps = ManagedRepresentatives(report);
        final provider = await openScreen(
          tester,
          report,
          reps,
          brightness: brightness,
        );
        final month = provider.month;
        await tester.tap(find.text('Уволенный представитель'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Активировать'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(reps.patches, isEmpty);
        reps.fail = true;
        await tester.tap(find.text('Активировать'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Активировать').last);
        await tester.pumpAndSettle();
        expect(report.active, isFalse);
        expect(
          find.textContaining('Не удалось изменить активность'),
          findsOneWidget,
        );
        reps.fail = false;
        reps.gate = Completer<void>();
        await tester.tap(find.text('Активировать'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Активировать').last);
        await tester.pump();
        final activity = tester.widget<AppSecondaryButton>(
          find.widgetWithText(AppSecondaryButton, 'Активировать'),
        );
        expect(activity.onPressed, isNull);
        expect(
          tester
              .widget<AppSecondaryButton>(
                find.widgetWithText(AppSecondaryButton, 'Закрыть'),
              )
              .onPressed,
          isNull,
        );
        reps.gate!.complete();
        await tester.pumpAndSettle();
        expect(report.active, isTrue);
        expect(find.text('Деактивировать'), findsOneWidget);
        expect(find.text('Неактивный клиент'), findsOneWidget);
        expect(find.text('Передан / снят'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(RepresentativeCommissionDialog),
            matching: find.text('3.75 ₽'),
          ),
          findsNWidgets(2),
        );
        await tester.tap(find.text('Деактивировать'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Деактивировать').last);
        await tester.pumpAndSettle();
        expect(report.active, isFalse);
        expect(reps.patches.last, {'isActive': false});
        expect(find.text('Активировать'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RepresentativeCommissionDialog),
            matching: find.text('3.75 ₽'),
          ),
          findsNWidgets(2),
        );
        expect(report.assignments, isEmpty);
        final calls = report.calls.length;
        await tester.tap(find.text('Закрыть'));
        await tester.pumpAndSettle();
        expect(report.calls.length, calls + 1);
        expect(provider.month, month);
        expect(provider.report!.representatives.first.isActive, isFalse);
        expect(
          provider.report!.representatives.first.payable.formatted,
          '3.75 ₽',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('add representative card is first and works for empty list', (
    tester,
  ) async {
    final report = ManagedReport()..empty = true;
    final reps = ManagedRepresentatives(report);
    final provider = await openScreen(tester, report, reps);
    expect(find.text('Добавить представителя'), findsOneWidget);
    final month = provider.month;
    final calls = report.calls.length;
    await tester.tap(find.text('Добавить представителя'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(reps.creates, 0);
    expect(report.calls.length, calls);
    await tester.tap(find.text('Добавить представителя'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Новый агент');
    await tester.enterText(fields.at(1), '9123456789');
    await tester.enterText(fields.at(2), '5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(reps.creates, 1);
    expect(find.text('Новый агент'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Добавить представителя')).dy,
      lessThan(tester.getTopLeft(find.text('Новый агент')).dy),
    );
    expect(provider.month, month);
    expect(tester.takeException(), isNull);
  });
}
