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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Отчёт по продажам',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Оборот и количество товаров по способам оплаты.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
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
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                if (report.paymentMethods.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Способы оплаты не настроены.'),
                    ),
                  )
                else
                  for (final method in report.paymentMethods)
                    _PaymentMethodCard(method: method),
              ],
            ),
          ),
      ],
    );
  }
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onSelectPeriod,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('Период: $period'),
                ),
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
      child: Column(
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
