import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_amount.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';

class CommissionsSummaryPanel extends StatelessWidget {
  final CommissionReport report;
  final CommissionMode mode;
  const CommissionsSummaryPanel({
    super.key,
    required this.report,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Semantics(
        container: true,
        label: 'Сводка комиссионных начислений',
        child: Material(
          key: const ValueKey('commissions-summary-surface'),
          elevation: 2,
          shadowColor: colors.shadow.withValues(alpha: .18),
          surfaceTintColor: Colors.transparent,
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.summarize_outlined,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      header: true,
                      child: Text(
                        'Итоги месяца',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final mainColumns = constraints.maxWidth >= 520 * scale
                        ? 2
                        : 1;
                    final detailColumns = (constraints.maxWidth / (220 * scale))
                        .floor()
                        .clamp(1, 3);
                    Widget grid(List<Widget> cells, int columns) {
                      final width =
                          (constraints.maxWidth - 24 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          for (final cell in cells)
                            SizedBox(width: width, child: cell),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        grid([
                          _SummaryValue(
                            'Общий оборот',
                            formatCommissionCents(report.totalTurnover),
                            prominent: true,
                          ),
                          _SummaryValue(
                            'Всего к выплате',
                            formatCommissionCents(report.totalPayable),
                            prominent: true,
                            accent: true,
                          ),
                        ], mainColumns),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(
                            height: 1,
                            color: colors.outlineVariant,
                          ),
                        ),
                        grid([
                          _SummaryValue(
                            'Представителям',
                            formatCommissionCents(
                              report.representativesPayable,
                            ),
                          ),
                          _SummaryValue(
                            'Сотрудникам',
                            formatCommissionCents(report.employeesPayable),
                          ),
                          _SummaryValue(
                            mode == CommissionMode.representatives
                                ? 'Оборот представителей'
                                : 'Общая база сотрудников',
                            formatCommissionCents(
                              mode == CommissionMode.representatives
                                  ? report.representedTurnover
                                  : report.totalTurnover,
                            ),
                          ),
                        ], detailColumns),
                      ],
                    );
                  },
                ),
              ],
            ),
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
  final bool accent;
  const _SummaryValue(
    this.label,
    this.value, {
    this.prominent = false,
    this.accent = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: label,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style:
                  (prominent
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                        fontWeight: prominent
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: accent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
