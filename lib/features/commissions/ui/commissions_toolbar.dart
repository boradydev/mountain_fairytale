import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_amount.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_widgets.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_metric_help.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/ui/month_picker_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';

class CommissionsToolbar extends StatelessWidget {
  final CommissionsProvider provider;
  final CommissionReport? report;
  const CommissionsToolbar({super.key, required this.provider, this.report});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final scale = math.max(1.0, textScaler.scale(14) / 14);
    final controlHeight = math.max(48.0, textScaler.scale(14) * 1.4 + 24);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        key: const ValueKey('commissions-toolbar-surface'),
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final selector = SegmentedButton<CommissionMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CommissionMode.representatives,
                    label: Text('Представители'),
                    icon: Icon(Icons.people_outline),
                  ),
                  ButtonSegment(
                    value: CommissionMode.employees,
                    label: Text('Сотрудники'),
                    icon: Icon(Icons.badge_outlined),
                  ),
                ],
                selected: {provider.mode},
                onSelectionChanged: (selection) =>
                    provider.setMode(selection.single),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: colors.primary,
                  selectedForegroundColor: colors.onPrimary,
                ),
              );
              final filter = SizedBox(
                width: 300 * scale,
                height: controlHeight,
                child: Center(
                  child: LabeledCheckboxToggle(
                    label: 'Деактивированные',
                    value: provider.includeDeactivated,
                    onChanged: provider.setIncludeDeactivated,
                    tooltip: provider.mode == CommissionMode.representatives
                        ? 'Показать всех представителей, включая деактивированных без клиентов и начислений'
                        : 'Показать деактивированных сотрудников со ставкой, даже без начислений',
                  ),
                ),
              );

              final monthControl = SizedBox(
                width: 300 * scale,
                height: controlHeight,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Предыдущий месяц',
                      onPressed: provider.loading
                          ? null
                          : () => provider.setMonth(
                              DateTime(
                                provider.month.year,
                                provider.month.month - 1,
                              ),
                            ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        key: const ValueKey('commissions-month-control'),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          commissionPeriodLabel(provider.month),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () async {
                          final month = await showDialog<DateTime>(
                            context: context,
                            builder: (_) => MonthPickerDialog(
                              initialMonth: provider.month,
                            ),
                          );
                          if (month != null && context.mounted) {
                            await provider.setMonth(month);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Следующий месяц',
                      onPressed: provider.loading
                          ? null
                          : () => provider.setMonth(
                              DateTime(
                                provider.month.year,
                                provider.month.month + 1,
                              ),
                            ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              );

              final controls = Wrap(
                spacing: 16 * scale,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [selector, filter, monthControl],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: controlHeight),
                    child: controls,
                  ),
                  if (report != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: colors.outlineVariant),
                    ),
                    _CommissionSummary(report: report!, mode: provider.mode),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CommissionSummary extends StatelessWidget {
  final CommissionReport report;
  final CommissionMode mode;
  const _CommissionSummary({required this.report, required this.mode});

  @override
  Widget build(BuildContext context) {
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final items = <(String, String, bool)>[
      ('Общий оборот', formatCommissionCents(report.totalTurnover), false),
      ('Всего к выплате', formatCommissionCents(report.totalPayable), true),
      (
        'Представителям',
        formatCommissionCents(report.representativesPayable),
        false,
      ),
      ('Сотрудникам', formatCommissionCents(report.employeesPayable), false),
      (
        mode == CommissionMode.representatives
            ? 'Оборот представителей'
            : 'Оборот сотрудников',
        formatCommissionCents(
          mode == CommissionMode.representatives
              ? report.representedTurnover
              : report.employeeTurnover.cents,
        ),
        false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / (190 * scale)).floor().clamp(
          1,
          5,
        );
        final spacing = 20.0 * scale;
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: [
            for (final (label, value, prominent) in items)
              SizedBox(
                width: cellWidth,
                child: _CommissionSummaryValue(
                  label,
                  value,
                  prominent: prominent,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CommissionSummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final bool prominent;
  const _CommissionSummaryValue(
    this.label,
    this.value, {
    required this.prominent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: commissionMetricHelp(label),
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (prominent
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: prominent ? FontWeight.w600 : FontWeight.w500,
                      color: prominent ? theme.colorScheme.primary : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
          ),
        ],
      ),
    );
  }
}
