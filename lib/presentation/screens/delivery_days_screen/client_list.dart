import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:provider/provider.dart';

class ClientsAttentionListView extends StatelessWidget {
  const ClientsAttentionListView({super.key});

  @override
  Widget build(BuildContext context) {
    final clients = context.select((ClientsProvider p) => p.sortedClients);

    if (clients.isEmpty) {
      return const Center(child: Text('Клиенты отсутствуют'));
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

    final lastDeliveryText = client.lastDeliveryDate == null
        ? 'Доставок ещё не было'
        : 'Последняя доставка: '
              '${client.lastDeliveryDate!.day.toString().padLeft(2, '0')}.'
              '${client.lastDeliveryDate!.month.toString().padLeft(2, '0')}.'
              '${client.lastDeliveryDate!.year}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              client.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(client.phone),
            const SizedBox(height: 4),
            Text(lastDeliveryText),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: звонок
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Позвонить'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // TODO: cooldown
                  },
                  icon: const Icon(Icons.snooze),
                  tooltip: 'Отложить',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
