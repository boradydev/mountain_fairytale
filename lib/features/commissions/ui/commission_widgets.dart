import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/active_status_label.dart';

import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_metric_help.dart';

class CommissionMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? tooltip;
  const CommissionMetric(this.label, this.value, {super.key, this.tooltip});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? commissionMetricHelp(label),
    constraints: const BoxConstraints(maxWidth: 360),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class CommissionRates extends StatelessWidget {
  final List<CommissionRate> rates;
  const CommissionRates(this.rates, {super.key});
  @override
  Widget build(BuildContext context) => rates.isEmpty
      ? const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Начислений за этот месяц нет'),
        )
      : Column(
          children: [
            for (final rate in rates)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    CommissionMetric('Ставка', '${rate.percent}%'),
                    CommissionMetric(
                      'Оборотная база',
                      rate.turnover.formatted,
                      tooltip:
                          'Оборот за выбранный месяц, к которому применялась эта сохранённая ставка. '
                          'Используется для расчёта начисления в этой строке.',
                    ),
                    CommissionMetric('Начислено', rate.payable.formatted),
                  ],
                ),
              ),
          ],
        );
}

class CommissionPersonHeader extends StatelessWidget {
  final String name;
  final bool isActive;
  final TextStyle? nameStyle;

  const CommissionPersonHeader({
    super.key,
    required this.name,
    required this.isActive,
    this.nameStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            name,
            style:
                nameStyle ??
                theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
          ),
        ),
        const SizedBox(width: 12),
        ActiveStatusLabel(isActive: isActive),
      ],
    );
  }
}

const commissionMonths = [
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

String commissionPeriodLabel(DateTime month) =>
    '${commissionMonths[month.month - 1]} ${month.year}';
