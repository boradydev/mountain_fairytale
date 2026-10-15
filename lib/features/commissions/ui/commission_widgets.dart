import 'package:flutter/material.dart';

import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';

class CommissionMetric extends StatelessWidget {
  final String label;
  final String value;
  const CommissionMetric(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
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
                    CommissionMetric('Оборотная база', rate.turnover.formatted),
                    CommissionMetric('Начислено', rate.payable.formatted),
                  ],
                ),
              ),
          ],
        );
}

class CommissionInactiveLabel extends StatelessWidget {
  const CommissionInactiveLabel({super.key});
  @override
  Widget build(BuildContext context) => Text(
    'Деактивирован',
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
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
