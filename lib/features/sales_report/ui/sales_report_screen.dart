import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/sales_report/data/sales_report_model.dart';
import 'package:mountain_fairytale/features/sales_report/ui/sales_report_provider.dart';
import 'package:mountain_fairytale/shared/utils/app_date_range_picker.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/metric_row_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) {
          context.read<SalesReportProvider>().refresh();
        }
      });
    }
    _visible = visible;
  }

  Future<void> _selectPeriod(SalesReportProvider provider) async {
    final range = await showAppDateRangePicker(
      context,
      initialDateRange: provider.dateRange,
      helpText: 'Период продаж',
    );
    if (!mounted || range == null) return;
    await provider.setDateRange(range);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesReportProvider>();
    final report = provider.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SalesReportToolbar(
          provider: provider,
          onSelectPeriod: () => _selectPeriod(provider),
        ),
        SizedBox(
          height: 3,
          child: provider.status == SalesReportStatus.loading
              ? const LinearProgressIndicator(minHeight: 3)
              : null,
        ),
        if (provider.status == SalesReportStatus.failure && report == null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.errorMessage),
                  const SizedBox(height: 8),
                  AppSecondaryButton(
                    text: 'Повторить',
                    onPressed: provider.refresh,
                  ),
                ],
              ),
            ),
          )
        else if (report == null)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: Column(
              children: [
                if (provider.status == SalesReportStatus.failure)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(provider.errorMessage)),
                        AppSecondaryButton(
                          text: 'Повторить',
                          onPressed: provider.refresh,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: report.paymentMethods.isEmpty
                      ? const Center(
                          child: Text('Способы оплаты не настроены.'),
                        )
                      : _PaymentMethodCards(methods: report.paymentMethods),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentMethodCards extends StatefulWidget {
  final List<SalesReportPaymentMethod> methods;

  const _PaymentMethodCards({required this.methods});

  @override
  State<_PaymentMethodCards> createState() => _PaymentMethodCardsState();
}

class _PaymentMethodCardsState extends State<_PaymentMethodCards> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - 32)
          .clamp(0.0, 380.0)
          .toDouble();
      final rowWidth =
          widget.methods.length * cardWidth +
          (widget.methods.length - 1) * 16 +
          32;
      final contentWidth = rowWidth < constraints.maxWidth
          ? constraints.maxWidth
          : rowWidth;
      // Both scrollbars belong to the visible viewport. The horizontal bar stays
      // reachable even when a tall card requires vertical scrolling.
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _vertical,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.vertical,
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: contentWidth,
                child: ListView(
                  controller: _vertical,
                  primary: false,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < widget.methods.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(width: 16),
                          SizedBox(
                            width: cardWidth,
                            child: _PaymentMethodCard(
                              method: widget.methods[index],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SalesReportToolbar extends StatelessWidget {
  final SalesReportProvider provider;
  final VoidCallback onSelectPeriod;

  const _SalesReportToolbar({
    required this.provider,
    required this.onSelectPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final report = provider.report;
    final range = provider.dateRange;
    final format = DateFormat('dd.MM.yyyy');
    final period =
        '${format.format(range.start)} — ${format.format(range.end)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        key: const ValueKey('sales-report-toolbar-surface'),
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleStyle = Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600);
                  final textScaler = MediaQuery.textScalerOf(context);
                  double textWidth(String text, TextStyle? style) {
                    final painter = TextPainter(
                      text: TextSpan(text: text, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: textScaler,
                    )..layout();
                    final width = painter.width;
                    painter.dispose();
                    return width;
                  }

                  final title = Text(
                    'Отчёт по продажам',
                    style: titleStyle,
                  );
                  final periodButton = AppSecondaryButton(
                    text: period,
                    icon: Icons.date_range,
                    onPressed: onSelectPeriod,
                  );
                  // Include the button padding, icon, gap and outline so the
                  // first row only stays horizontal when both labels fit.
                  final requiredWidth =
                      textWidth('Отчёт по продажам', titleStyle) +
                      16 +
                      textWidth(
                        period,
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ) +
                      68;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: requiredWidth <= constraints.maxWidth
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [title, periodButton],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              title,
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: periodButton,
                              ),
                            ],
                          ),
                  );
                },
              ),
              if (report != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: colors.outlineVariant),
                ),
                Wrap(
                  spacing: 32,
                  runSpacing: 12,
                  children: [
                    _SummaryValue(
                      label: 'Оборот за период',
                      value: '${report.totalAmount} ₽',
                      prominent: true,
                    ),
                    _SummaryValue(
                      label: 'Продано товаров',
                      value: '${report.totalQuantity} шт.',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final bool prominent;

  const _SummaryValue({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style:
              (prominent
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.titleMedium)
                  ?.copyWith(
                    fontWeight: prominent ? FontWeight.w600 : FontWeight.w500,
                    color: prominent ? theme.colorScheme.primary : null,
                  ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final SalesReportPaymentMethod method;

  const _PaymentMethodCard({required this.method});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppBaseCard(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  method.paymentMethodName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${method.totalAmount} ₽',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: colors.outlineVariant, height: 1),
          const SizedBox(height: 8),
          if (method.products.isEmpty)
            Text(
              'Продаж не было',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          else
            for (final product in method.products)
              MetricRow(
                icon: Icons.shopping_bag_outlined,
                label: product.productName,
                truncateLabel: true,
                value: '${product.quantity} шт.',
              ),
        ],
      ),
    );
  }
}
