import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/presentation/providers/sales_representative_commission_provider.dart';
import 'package:mountain_fairytale/presentation/providers/sales_representative_clients_provider.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/widgets/metric_row_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/app_notify.dart';
import 'package:mountain_fairytale/presentation/screens/common/sales_rep_select_dialog.dart';

class SalesRepresentativeDetailsDialog extends StatelessWidget {
  const SalesRepresentativeDetailsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final clientsProvider = context.watch<SalesRepresentativeClientsProvider>();
    final commProvider = context.read<SalesRepresentativeCommissionProvider>();

    // Находим данные по текущему представителю из списка комиссий
    final commission = commProvider.commissions.firstWhere(
      (c) => c.salesRepresentativeId == clientsProvider.currentRepresentativeId,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1100,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              commission.salesRepresentativeName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricRow(
                    label: 'Процент',
                    value: '${commission.commissionPercent}%',
                  ),
                ),
                Expanded(
                  child: MetricRow(
                    label: 'Оборот',
                    value:
                        '${commission.totalSalesAmount.toStringAsFixed(2)} ₽',
                  ),
                ),
                Expanded(
                  child: MetricRow(
                    label: 'К выплате',
                    value:
                        '${commission.commissionAmount.toStringAsFixed(2)} ₽',
                    valueColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Клиенты за период',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск клиента...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => clientsProvider.setSearchQuery(val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: clientsProvider.status == SalesRepClientsStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: clientsProvider.filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = clientsProvider.filteredClients[index];
                        return AppBaseCard(
                          child: Row(
                            children: [
                              // Левая часть: Имя и телефон
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      client.clientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      client.phone,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              // Правая часть: Метрики
                              Row(
                                children: [
                                  MetricRow(
                                    label: 'Заказов',
                                    value: client.ordersCount.toString(),
                                    valueWidth: 30,
                                  ),
                                  const SizedBox(width: 12),
                                  MetricRow(
                                    label: 'Оборот',
                                    value:
                                        '${client.totalSalesAmount.toStringAsFixed(2)} ₽',
                                    valueWidth: 70,
                                  ),
                                  const SizedBox(width: 12),
                                  MetricRow(
                                    label: 'К выплате',
                                    value:
                                        '${client.commissionAmount.toStringAsFixed(2)} ₽',
                                    valueWidth: 70,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                AppSecondaryButton(
                  text: 'Отмена',
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                AppSecondaryButton(
                  text: 'Снять представителя',
                  onPressed: () async {
                    final confirmed = await ConfirmDialog.show(
                      context,
                      title: 'Снять представителя?',
                      content: 'Вы действительно хотите снять всех клиентов у представителя?',
                      confirmText: 'Подтвердить',
                      destructive: true,
                    );
                    if (confirmed) {
                      await clientsProvider.clearRepresentative();
                      AppNotify.show(
                        'Представитель снят со всех клиентов',
                      );
                      commProvider.fetchCommissions();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(width: 12),
                AppPrimaryButton(
                  text: 'Передать клиентов',
                  onPressed: () async {
                    final repProvider = context.read<ClientsProvider>();
                    final selected = await showDialog<SalesRepresentative?>(
                      context: context,
                      builder: (_) => SalesRepSelectDialog(
                        reps: repProvider.salesRepresentatives,
                      ),
                    );

                    if (selected != null) {
                      final confirmed = await ConfirmDialog.show(
                        context,
                        title: 'Передать клиентов?',
                        content:
                            'Вы действительно хотите передать всех клиентов представителю ${selected.name}?',
                        confirmText: 'Подтвердить',
                      );

                      if (confirmed) {
                        await clientsProvider.assignClientsTo(selected.id);
                        AppNotify.show(
                          'Клиенты переданы представителю ${selected.name}',
                        );
                        commProvider.fetchCommissions();
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
