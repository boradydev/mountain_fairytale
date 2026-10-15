import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/ui/month_picker_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

import 'package:mountain_fairytale/features/commissions/data/commission_amount.dart';
import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_widgets.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';
import 'package:mountain_fairytale/features/commissions/ui/representative_commission_dialog.dart';

class CommissionsScreen extends StatefulWidget {
  const CommissionsScreen({super.key});
  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen>
    with WidgetsBindingObserver {
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) context.read<CommissionsProvider>().refresh();
      });
    }
    _visible = visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible && mounted) {
      context.read<CommissionsProvider>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommissionsProvider>();
    final report = provider.report;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<CommissionMode>(
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
                onSelectionChanged: (value) => provider.setMode(value.single),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: colors.primary,
                  selectedForegroundColor: colors.onPrimary,
                ),
              ),
              if (provider.mode == CommissionMode.representatives)
                Tooltip(
                  message: 'Показать всех представителей, включая деактивированных без клиентов и начислений',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: provider.includeDeactivated,
                        onChanged: provider.setIncludeDeactivated,
                      ),
                      const SizedBox(width: 8),
                      const Text('Деактивированные'),
                    ],
                  ),
                ),
              AppSecondaryButton(
                text: commissionPeriodLabel(provider.month),
                onPressed: () async {
                  final selected = await showDialog<DateTime>(
                    context: context,
                    builder: (_) =>
                        MonthPickerDialog(initialMonth: provider.month),
                  );
                  if (selected != null && context.mounted) {
                    await provider.setMonth(selected);
                  }
                },
              ),
              AppSecondaryButton(
                text: 'Обновить',
                onPressed: provider.loading ? null : provider.refresh,
              ),
            ],
          ),
        ),
        if (provider.loading) const LinearProgressIndicator(),
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              children: [
                Text(provider.error!),
                AppSecondaryButton(
                  text: 'Повторить',
                  onPressed: provider.refresh,
                ),
              ],
            ),
          ),
        if (report != null) _Summary(report, provider.mode),
        Expanded(
          child: report == null
              ? Center(
                  child: Text(
                    provider.loading ? 'Загрузка начислений…' : 'Нет данных',
                  ),
                )
              : provider.mode == CommissionMode.representatives
              ? _representatives(context, provider, report)
              : _employees(context, provider, report),
        ),
      ],
    );
  }

  Widget _representatives(
    BuildContext context,
    CommissionsProvider provider,
    CommissionReport report,
  ) {
    if (report.representatives.isEmpty) {
      return const Center(child: Text('Представителей нет'));
    }
    return ListView.builder(
      itemCount: report.representatives.length,
      itemBuilder: (context, index) {
        final row = report.representatives[index];
        return AppBaseCard(
          onTap: () async {
            final changed = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => RepresentativeCommissionDialog(
                repository: provider.repository,
                representativeId: row.id,
                month: provider.month,
                targets: report.representatives
                    .where((item) => item.isActive && item.id != row.id)
                    .toList(),
              ),
            );
            if (!context.mounted) return;
            if (changed == true) {
              await provider.refresh();
              if (context.mounted) {
                await context
                    .read<ClientsProvider?>()
                    ?.refreshDashboardClients();
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.name, style: Theme.of(context).textTheme.titleMedium),
              if (!row.isActive) const CommissionInactiveLabel(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  CommissionMetric(
                    'Клиентов закреплено',
                    '${row.assignedClientsCount}',
                  ),
                  CommissionMetric('Заказов', '${row.ordersCount}'),
                  CommissionMetric('Оборот', row.turnover.formatted),
                  CommissionMetric('К выплате', row.payable.formatted),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _employees(
    BuildContext context,
    CommissionsProvider provider,
    CommissionReport report,
  ) {
    if (report.employees.isEmpty) {
      return const Center(child: Text('Сотрудников нет'));
    }
    return ListView.builder(
      itemCount: report.employees.length,
      itemBuilder: (context, index) {
        final row = report.employees[index];
        return AppBaseCard(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(
                '${row.name} · ${commissionPeriodLabel(provider.month)}',
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 600,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 28,
                        runSpacing: 12,
                        children: [
                          CommissionMetric(
                            'Оборотная база',
                            row.turnover.formatted,
                          ),
                          CommissionMetric('К выплате', row.payable.formatted),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Начисления по фактическим ставкам'),
                      CommissionRates(row.rates),
                    ],
                  ),
                ),
              ),
              actions: [
                AppSecondaryButton(
                  text: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.name, style: Theme.of(context).textTheme.titleMedium),
              if (!row.isActive) const CommissionInactiveLabel(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  CommissionMetric('Оборотная база', row.turnover.formatted),
                  CommissionMetric('К выплате', row.payable.formatted),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final CommissionReport report;
  final CommissionMode mode;
  const _Summary(this.report, this.mode);
  @override
  Widget build(BuildContext context) => AppBaseCard(
    child: Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        CommissionMetric(
          'Общий оборот',
          formatCommissionCents(report.totalTurnover),
        ),
        CommissionMetric(
          'Всего к выплате',
          formatCommissionCents(report.totalPayable),
        ),
        CommissionMetric(
          'Представителям',
          formatCommissionCents(report.representativesPayable),
        ),
        CommissionMetric(
          'Сотрудникам',
          formatCommissionCents(report.employeesPayable),
        ),
        CommissionMetric(
          mode == CommissionMode.representatives
              ? 'Оборот представителей'
              : 'Общая база сотрудников',
          formatCommissionCents(
            mode == CommissionMode.representatives
                ? report.representedTurnover
                : report.totalTurnover,
          ),
        ),
      ],
    ),
  );
}
