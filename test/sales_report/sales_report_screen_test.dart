import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/sales_report/data/sales_report_model.dart';
import 'package:mountain_fairytale/features/sales_report/sales_report_abcs.dart';
import 'package:mountain_fairytale/features/sales_report/ui/sales_report_provider.dart';
import 'package:mountain_fairytale/features/sales_report/ui/sales_report_screen.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:provider/provider.dart';

class _Repository implements SalesReportRepository {
  int calls = 0;
  final List<SalesReportPaymentMethod> methods;
  _Repository({this.methods = const []});

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
      paymentMethods: methods,
    );
  }
}

void main() {
  final methods = List.generate(
    5,
    (index) => SalesReportPaymentMethod(
      paymentMethodId: 'method-$index',
      paymentMethodName: 'Способ оплаты $index',
      isActive: true,
      totalQuantity: 1,
      totalAmount: '100.00',
      products: List.generate(
        [1, 30, 2, 0, 3][index],
        (product) => SalesReportProduct(
          productId: 'product-$product',
          productName: 'Товар $product',
          quantity: 1,
          amount: '100.00',
        ),
      ),
    ),
  );

  for (final width in [1000.0, 380.0]) {
    testWidgets(
      'payment cards stay in one row with independent horizontal and vertical scrolling at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = SalesReportProvider(_Repository(methods: methods));
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: const MaterialApp(home: Scaffold(body: SalesReportScreen())),
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byType(AppBaseCard);
        expect(cards, findsNWidgets(5));
        final first = tester.getRect(cards.at(0));
        final second = tester.getRect(cards.at(1));
        final third = tester.getRect(cards.at(2));
        expect(first.width, width >= 808 ? 380 : width - 32);
        expect(second.width, first.width);
        expect(second.height, greaterThan(first.height));
        expect(second.top, first.top);
        expect(third.top, first.top);
        expect(second.left - first.right, 16);
        expect(third.left - second.right, 16);
        final horizontal = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.right,
        );
        final vertical = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        final horizontalPosition = tester
            .state<ScrollableState>(horizontal)
            .position;
        final verticalPosition = tester
            .state<ScrollableState>(vertical)
            .position;
        expect(horizontalPosition.maxScrollExtent, greaterThan(0));
        expect(verticalPosition.maxScrollExtent, greaterThan(0));
        final bottomBar = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollbar &&
              widget.scrollbarOrientation == ScrollbarOrientation.bottom,
        );
        expect(tester.getBottomRight(bottomBar).dy, 900);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(-2400, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Способ оплаты 4').hitTestable(), findsOneWidget);
        expect(verticalPosition.pixels, 0);
        final horizontalOffset = horizontalPosition.pixels;
        await tester.dragFrom(
          tester.getTopLeft(bottomBar) + Offset(width / 2, 80),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(verticalPosition.pixels, greaterThan(0));
        expect(horizontalPosition.pixels, horizontalOffset);
        expect(tester.getBottomRight(bottomBar).dy, 900);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('two cards fit side by side without horizontal overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = SalesReportProvider(
      _Repository(methods: methods.take(2).toList()),
    );
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SalesReportScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.right,
    );
    expect(
      tester.state<ScrollableState>(horizontal).position.maxScrollExtent,
      0,
    );
    final cards = find.byType(AppBaseCard);
    expect(tester.getRect(cards.first).top, tester.getRect(cards.last).top);
    expect(find.text('Способ оплаты 0').hitTestable(), findsOneWidget);
    expect(find.text('Способ оплаты 1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to the tab refreshes sales for the selected period', (
    tester,
  ) async {
    final repository = _Repository();
    final provider = SalesReportProvider(
      repository,
      now: DateTime(2026, 11, 1),
    );
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
