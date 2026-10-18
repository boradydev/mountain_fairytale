import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';

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

class CommissionStatusLabel extends StatelessWidget {
  final bool isActive;

  const CommissionStatusLabel({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final success = theme.extension<AppColorsExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isActive
        ? success?.successColor ??
              (isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20))
        : colors.onSurfaceVariant;

    return Text(
      isActive ? 'Активен' : 'Деактивирован',
      style: theme.textTheme.labelMedium?.copyWith(color: foreground),
    );
  }
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
        CommissionStatusLabel(isActive: isActive),
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
