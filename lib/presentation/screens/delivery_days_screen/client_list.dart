import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/utils/datetime_extensions.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/card_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/metric_row_widget.dart';
import 'package:provider/provider.dart';

class ClientsAttentionListView extends StatelessWidget {
  const ClientsAttentionListView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Сначала проверяем статус
    final status = context.select((ClientsProvider p) => p.status);

    if (status == ClientStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == ClientStatus.failure) {
      final error = context.select((ClientsProvider p) => p.errorMessage);
      return Center(child: Text('Ошибка: $error'));
    }

    // 2. Только при успехе берем клиентов
    final clients = context.select((ClientsProvider p) => p.sortedClients);

    if (clients.isEmpty) {
      return const Center(
        child: Text('Клиенты отсутствуют'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        return _ClientAttentionCard(client: client);
      },
    );
  }
}


class _ClientAttentionCard extends StatelessWidget {
  final Client client;

  const _ClientAttentionCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final lastDeliveryText = client.lastDeliveryDate == null
        ? 'Доставок ещё не было'
        : 'Последняя доставка: '
              '${client.lastDeliveryDate!.day.toString().padLeft(2, '0')}.'
              '${client.lastDeliveryDate!.month.toString().padLeft(2, '0')}.'
              '${client.lastDeliveryDate!.year}';

    return DeliveryDayCard(
      title: '${client.name}. Адрес: ${client.address}',
      onTap: () {
        // Логика перехода на детальный экран по day.id
      },
      metrics: [
        Row(
          children: [
            MetricRow(
              label: '${"Телефон:"}',
              labelWidth: 65,
              value: '${client.phone}',
          ),
            const SizedBox(width: 16),
            MetricRow(
              label: '${"Последняя доставка:"}',
              labelWidth: 140,
              value: client.lastDeliveryDate?.toFormattedString() ?? 'никогда',

            ),],
        )
      ],
    );
  }
}
