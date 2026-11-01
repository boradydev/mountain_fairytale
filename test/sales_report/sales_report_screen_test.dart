import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/sales_report/data/sales_report_model.dart';
import 'package:mountain_fairytale/features/sales_report/sales_report_abcs.dart';
import 'package:mountain_fairytale/features/sales_report/ui/sales_report_provider.dart';
import 'package:mountain_fairytale/features/sales_report/ui/sales_report_screen.dart';
import 'package:provider/provider.dart';

class _Repository implements SalesReportRepository {
  int calls = 0;

  @override
  Future<SalesReport> getSalesReport({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    calls++;
    return SalesReport(
      dateFrom: dateFrom,
      dateTo: dateTo,
      totalQuantity: calls,
      totalAmount: '$calls.00',
      paymentMethods: const [],
    );
  }
}

void main() {
  testWidgets('returning to the tab refreshes sales for the selected period', (
    tester,
  ) async {
    final repository = _Repository();
    final provider = SalesReportProvider(repository, now: DateTime(2026, 11, 1));
    addTearDown(provider.dispose);
    var visible = true;
    late StateSetter update;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return TickerMode(
                  enabled: visible,
                  child: const SalesReportScreen(),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(find.text('1.00 ₽'), findsOneWidget);
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    update(() => visible = true);
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('2.00 ₽'), findsOneWidget);
    expect(provider.dateRange.start, DateTime(2026, 11, 1));
  });
}
