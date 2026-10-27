import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/auth/services/auth_service_impl.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_amount.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/data/commissions_repo.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_screen.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:provider/provider.dart';

import '../auth/auth_fakes.dart';

const repId = '019a1111-1111-7111-8111-111111111111';
const targetId = '019a1111-1111-7111-8111-111111111112';
Map<String, dynamic> rate(String percent, String turnover, String payable) => {
  'commissionPercent': percent,
  'turnoverBase': turnover,
  'commissionPayable': payable,
};
Map<String, dynamic> representative({
  String id = repId,
  bool assigned = true,
}) => {
  'salesRepresentativeId': id,
  'salesRepresentativeName': id == repId
      ? 'Уволенный представитель'
      : 'Новый представитель',
  'isActive': id != repId,
  'assignedClientsCount': assigned && id == repId ? 1 : 0,
  'clientsCount': id == repId ? 1 : 0,
  'ordersCount': id == repId ? 2 : 0,
  'turnover': id == repId ? '100.10' : '0',
  'commissionPayable': id == repId ? '3.7525' : '0',
  'commissionRateBreakdown': id == repId
      ? [rate('2.5', '50.10', '1.2525'), rate('5', '50', '2.5')]
      : [],
};
Map<String, dynamic> reportJson() => {
  'salesRepresentatives': [representative(), representative(id: targetId)],
  'employees': [
    {
      'employeeId': 'employee-uuid',
      'username': 'Менеджер',
      'isActive': true,
      'turnoverBase': '150.10',
      'commissionPayable': '1.87625',
      'commissionRateBreakdown': [rate('1.25', '150.10', '1.87625')],
    },
  ],
  'summary': {'unassignedTurnover': '50.00', 'employeeTurnover': '75.00'},
};
Map<String, dynamic> detailsJson(bool assigned) => {
  ...representative(assigned: assigned),
  'clients': [
    {
      'clientId': 'client-uuid',
      'clientName': 'Неактивный клиент',
      'phone': '+79991234567',
      'isActive': false,
      'isCurrentlyAssigned': assigned,
      'ordersCount': 2,
      'lastOrderDate': '2026-10-12',
      'turnover': '100.10',
      'commissionPayable': '3.7525',
      'commissionRateBreakdown': [
        rate('2.5', '50.10', '1.2525'),
        rate('5', '50', '2.5'),
      ],
    },
  ],
};

class FakeCommissions implements CommissionsRepository {
  final calls = <(DateTime, bool)>[];
  final assignments = <(String, String?)>[];
  bool assigned = true;
  @override
  Future<CommissionReport> report(
    DateTime month, {
    required bool includeDeactivated,
  }) async {
    calls.add((month, includeDeactivated));
    return CommissionReport.fromJson(reportJson());
  }

  @override
  Future<RepresentativeCommissionDetails> details(
    String id,
    DateTime month,
  ) async => RepresentativeCommissionDetails.fromJson(detailsJson(assigned));
  @override
  Future<int> assign(String sourceId, String? targetId) async {
    assignments.add((sourceId, targetId));
    assigned = false;
    return 1;
  }
}

void main() {
  test('decimal HALF_UP rounding and sums use exact values without double arithmetic', () {
    expect(const CommissionAmount('0.005').cents, BigInt.one);
    expect(
      const CommissionAmount('1.004999999999999999999999').cents,
      BigInt.from(100),
    );
    expect(const CommissionAmount('1e-3').cents, BigInt.zero);
    expect(
      const CommissionAmount('9999999999999999.995').formatted,
      '10000000000000000.00 ₽',
    );
    final report = CommissionReport.fromJson(reportJson());
    expect(report.totalTurnover, BigInt.from(15010));
    expect(report.totalPayable, BigInt.from(563));
    expect(
      report.representativesPayable + report.employeesPayable,
      report.totalPayable,
    );
    final detail = detailsJson(true);
    final customer = Map<String, dynamic>.from(
      (detail['clients'] as List).first as Map,
    );
    detail['commissionPayable'] = '0.01';
    detail['clients'] = [
      {...customer, 'commissionPayable': '0.005'},
      {...customer, 'clientId': 'another-client', 'commissionPayable': '0.005'},
    ];
    // A person's card and dialog show the same saved amount. The monthly
    // overall summary sums rounded person amounts without recalculating rates.
    expect(
      RepresentativeCommissionDetails.fromJson(detail).payableCents,
      BigInt.one,
    );
  });

  test('API routes unwrap exact decimal values and transfer UUIDs including null', () async {
    final transport = RecordingTransport();
    final auth = AuthServiceImpl(
      repository: FakeAuthRepository(),
      tokenStorage: MemoryTokenStorage(),
    );
    await auth.login(username: 'manager', password: '');
    addTearDown(transport.close);
    addTearDown(auth.dispose);
    final repo = ApiCommissionsRepository(
      ApiClient(transport: transport, authService: auth, userAgent: 'test'),
    );
    transport.respond = (_) async => envelope(reportJson());
    final report = await repo.report(
      DateTime(2026, 10),
      includeDeactivated: true,
    );
    expect(report.representatives.first.payable.exact, '3.7525');
    expect(
      transport.requests.last.path,
      '/protected/commissions?year=2026&month=10&include_deactivated=true',
    );
    expect(
      transport.requests.last.headers!['Authorization'],
      'Bearer original-access',
    );
    transport.respond = (_) async => envelope(detailsJson(true));
    await repo.details(repId, DateTime(2026, 10));
    expect(
      transport.requests.last.path,
      '/protected/commissions/sales-representatives/$repId?year=2026&month=10',
    );
    transport.respond = (_) async => envelope({'updatedClientsCount': 1});
    expect(await repo.assign(repId, targetId), 1);
    expect(transport.requests.last.method, 'PUT');
    expect(transport.requests.last.body, {
      'targetSalesRepresentativeId': targetId,
    });
    await repo.assign(repId, null);
    expect(transport.requests.last.body, {'targetSalesRepresentativeId': null});
  });

  test(
    'stale month responses never overwrite the latest selected period',
    () async {
      final repo = _DelayedCommissions();
      final provider = CommissionsProvider(repo);
      addTearDown(provider.dispose);
      final first = provider.setMonth(DateTime(2026, 9));
      final second = provider.setMonth(DateTime(2026, 10));
      final latest = CommissionReport.fromJson(reportJson());
      repo.pending[1].complete(latest);
      await second;
      repo.pending[0].complete(
        const CommissionReport(
          representatives: [],
          employees: [],
          unassignedTurnover: CommissionAmount.zero,
        ),
      );
      await first;
      expect(provider.month, DateTime(2026, 10));
      expect(identical(provider.report, latest), isTrue);
    },
  );

  testWidgets(
    'modes share month and keep representative filter; inactive clients can be transferred',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeCommissions();
      final provider = CommissionsProvider(repo)..month = DateTime(2026, 10);
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: CommissionsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Уволенный представитель'), findsOneWidget);
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      expect(repo.calls.last.$2, isTrue);
      final calls = repo.calls.length;
      await tester.tap(find.text('Сотрудники'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LabeledCheckboxToggle>(find.byType(LabeledCheckboxToggle))
            .value,
        isTrue,
      );
      expect(find.text('Менеджер'), findsOneWidget);
      expect(repo.calls.length, calls);
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      expect(repo.calls.last.$2, isFalse);
      await tester.tap(find.byType(LabeledCheckboxToggle));
      await tester.pumpAndSettle();
      expect(repo.calls.last.$2, isTrue);
      await tester.tap(find.text('Менеджер'));
      await tester.pumpAndSettle();
      expect(find.text('1.25%'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Представители'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LabeledCheckboxToggle>(find.byType(LabeledCheckboxToggle))
            .value,
        isTrue,
      );
      await tester.tap(find.text('Уволенный представитель'));
      await tester.pumpAndSettle();
      expect(find.text('Неактивный клиент'), findsOneWidget);
      expect(find.text('Начисления по фактическим ставкам'), findsOneWidget);
      await tester.tap(find.text('Начисления по фактическим ставкам'));
      await tester.pumpAndSettle();
      expect(find.text('2.5%'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
      await tester.tap(find.text('Передать клиентов'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Новый представитель').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(repo.assignments.single, (repId, targetId));
      final transfer = tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Передать клиентов'),
      );
      expect(transfer.onPressed, isNull);
      expect(find.text('Передан / снят'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(repo.calls.length, calls + 3);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DelayedCommissions extends FakeCommissions {
  final pending = <Completer<CommissionReport>>[];
  @override
  Future<CommissionReport> report(
    DateTime month, {
    required bool includeDeactivated,
  }) {
    final done = Completer<CommissionReport>();
    pending.add(done);
    return done.future;
  }
}
