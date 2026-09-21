import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_commissions/models/sales_representative_commission_model.dart';
import 'package:mountain_fairytale/presentation/providers/sales_representative_commission_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class SalesRepresentativeCommissionScreen extends StatefulWidget {
  const SalesRepresentativeCommissionScreen({super.key});

  @override
  State<SalesRepresentativeCommissionScreen> createState() =>
      _SalesRepresentativeCommissionScreenState();
}

class _SalesRepresentativeCommissionScreenState
    extends State<SalesRepresentativeCommissionScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesRepresentativeCommissionProvider>().fetchCommissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesRepresentativeCommissionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вознаграждение торговых представителей'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed:
                provider.status == SalesRepresentativeCommissionStatus.loading
                ? null
                : () => provider.fetchCommissions(),
          ),
        ],
      ),
      body: Column(
        children: [
          const _PeriodPanel(),
          const SizedBox(height: 12),
          const _TotalCommissionCard(),
          const SizedBox(height: 12),
          Expanded(
            child: _Content(provider: provider),
          ),
        ],
      ),
    );
  }
}

class _PeriodPanel extends StatelessWidget {
  const _PeriodPanel();

  static const _months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesRepresentativeCommissionProvider>();

    final month = _months[provider.dateFrom.month - 1];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$month ${provider.dateFrom.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppSecondaryButton(
              text: 'Выбрать месяц',
              onPressed: () => _selectMonth(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final provider = context.read<SalesRepresentativeCommissionProvider>();

    final selected = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(
        initialMonth: provider.dateFrom,
      ),
    );

    if (selected != null) {
      await provider.setMonth(selected);
    }
  }
}

class _TotalCommissionCard extends StatelessWidget {
  const _TotalCommissionCard();

  @override
  Widget build(BuildContext context) {
    final total = context.select(
      (SalesRepresentativeCommissionProvider p) => p.totalCommissionAmount,
    );

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Всего к выплате',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'За выбранный месяц',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Text(
              '${total.toStringAsFixed(2)} ₽',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final SalesRepresentativeCommissionProvider provider;

  const _Content({required this.provider});

  @override
  Widget build(BuildContext context) {
    switch (provider.status) {
      case SalesRepresentativeCommissionStatus.initial:
      case SalesRepresentativeCommissionStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case SalesRepresentativeCommissionStatus.failure:
        return _ErrorView(
          message: provider.errorMessage,
          onRetry: provider.fetchCommissions,
        );

      case SalesRepresentativeCommissionStatus.success:
        if (provider.commissions.isEmpty) {
          return const Center(child: Text('Нет данных за выбранный период'));
        }

        return _CommissionList(commissions: provider.commissions);
    }
  }
}

class _CommissionList extends StatelessWidget {
  final List<SalesRepresentativeCommission> commissions;

  const _CommissionList({required this.commissions});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: commissions.length,
      itemBuilder: (context, index) {
        return _CommissionCard(commission: commissions[index]);
      },
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final SalesRepresentativeCommission commission;

  const _CommissionCard({required this.commission});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    commission.salesRepresentativeName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _PercentBadge(percent: commission.commissionPercent),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Клиентов',
                    value: commission.clientsCount.toString(),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Оборот',
                    value: _formatMoney(commission.totalSalesAmount),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'К выплате',
                    value: _formatMoney(commission.commissionAmount),
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ₽';
  }
}

class _PercentBadge extends StatelessWidget {
  final double percent;

  const _PercentBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${percent.toStringAsFixed(1)}%',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _Metric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 17 : 15,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialMonth;

  const _MonthPickerDialog({
    required this.initialMonth,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  static const _months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  void initState() {
    super.initState();

    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выбор месяца'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _year--;
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_year',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _year++;
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 44,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final selected = month == _month;

                return OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _month = month;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  child: Text(_months[index]),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        AppSecondaryButton(
          text: 'Отмена',
          onPressed: () => Navigator.pop(context),
        ),
        AppPrimaryButton(
          text: 'Выбрать',
          onPressed: () {
            Navigator.pop(
              context,
              DateTime(_year, _month),
            );
          },
        ),
      ],
    );
  }
}
