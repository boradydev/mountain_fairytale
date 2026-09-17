import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/providers/pickup_constructor_provider.dart';
import 'package:provider/provider.dart';

class PickupMetaPanel extends StatefulWidget {
  const PickupMetaPanel({super.key});

  @override
  State<PickupMetaPanel> createState() => _PickupMetaPanelState();
}

class _PickupMetaPanelState extends State<PickupMetaPanel> {
  final TextEditingController _clientSearchController = TextEditingController();

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickupConstructorProvider>();
    final clientsProvider = context.watch<ClientsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final searchQuery = _clientSearchController.text.trim().toLowerCase();

    final filteredClients = clientsProvider.clients.where((client) {
      if (searchQuery.isEmpty) {
        return true;
      }

      return client.name.toLowerCase().contains(searchQuery) ||
          client.address.toLowerCase().contains(searchQuery) ||
          client.phone.toLowerCase().contains(searchQuery);
    }).toList();

    return Container(
      width: 360,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Самовывоз', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),

          const SizedBox(height: 24),

          const Text('Дата', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          InkWell(
            onTap: provider.isReadOnly
                ? null
                : () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: provider.selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );

                    if (selected != null) {
                      provider.setDate(selected);
                    }
                  },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(_formatDate(provider.selectedDate)),
            ),
          ),

          const SizedBox(height: 24),

          const Text('Клиенты', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          TextField(
            controller: _clientSearchController,
            enabled: !provider.isReadOnly,
            onChanged: (_) {
              setState(() {});
            },
            decoration: const InputDecoration(
              hintText: 'Поиск клиента...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: filteredClients.length,
              itemBuilder: (context, index) {
                final client = filteredClients[index];

                final alreadyAdded = provider.points.any(
                  (point) => point.clientId == client.id,
                );

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  enabled: !provider.isReadOnly && !alreadyAdded,
                  leading: Icon(
                    alreadyAdded
                        ? Icons.check_circle_outline
                        : Icons.person_add_alt_1_outlined,
                    color: alreadyAdded
                        ? colorScheme.outline
                        : colorScheme.primary,
                  ),
                  title: Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    client.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: alreadyAdded
                      ? null
                      : () {
                          provider.addClientPoint(client);
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
