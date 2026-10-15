import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_widgets.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_provider.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_toolbar.dart';
import 'package:mountain_fairytale/features/commissions/ui/representative_commission_dialog.dart';

class CommissionsScreen extends StatefulWidget {
  const CommissionsScreen({super.key});
  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen> {
  bool _visible = false;

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
  Widget build(BuildContext context) {
    final provider = context.watch<CommissionsProvider>();
    final report = provider.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommissionsToolbar(provider: provider, report: report),
        SizedBox(
          height: 3,
          child: provider.loading
              ? const LinearProgressIndicator(minHeight: 3)
              : null,
        ),
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
