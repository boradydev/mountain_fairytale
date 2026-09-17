import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days_screen/add_client_dialog.dart';
import 'package:provider/provider.dart';

class ClientSelectionPanel extends StatefulWidget {
  const ClientSelectionPanel({super.key});

  @override
  State<ClientSelectionPanel> createState() => _ClientSelectionPanelState();
}

class _ClientSelectionPanelState extends State<ClientSelectionPanel> {
  final TextEditingController _clientSearchController = TextEditingController();

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _showAddClientDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const ClientDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteConstructorProvider>();
    final clientProvider = context.watch<ClientsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final searchQuery = _clientSearchController.text.trim().toLowerCase();

    final filteredClients = clientProvider.clients.where((client) {
      if (searchQuery.isEmpty) return true;

      return client.name.toLowerCase().contains(searchQuery) ||
          client.address.toLowerCase().contains(searchQuery) ||
          client.phone.toLowerCase().contains(searchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '2. Быстрое добавление клиента',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () => _showAddClientDialog(context),
              icon: const Icon(Icons.add),
              tooltip: 'Добавить клиента',
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Имя, адрес или телефон',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _clientSearchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _clientSearchController.clear();
                      setState(() {});
                    },
                  ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: filteredClients.length,
            itemBuilder: (context, idx) {
              final client = filteredClients[idx];

              final isAlreadyAdded = provider.points.any(
                (point) => point.clientId == client.id,
              );

              return ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: isAlreadyAdded
                      ? 'Клиент уже добавлен в маршрут'
                      : 'Редактировать клиента',
                  visualDensity: VisualDensity.compact,
                  onPressed: isAlreadyAdded
                      ? null
                      : () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => ClientDialog(client: client),
                          );
                        },
                ),
                title: Text(
                  client.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isAlreadyAdded ? colorScheme.onSurfaceVariant : null,
                  ),
                ),
                subtitle: Text(
                  client.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isAlreadyAdded ? colorScheme.onSurfaceVariant : null,
                  ),
                ),
                trailing: isAlreadyAdded
                    ? const Icon(Icons.check_circle, color: Colors.grey)
                    : const Icon(Icons.add_circle, color: Colors.green),
                dense: true,
                onTap: isAlreadyAdded
                    ? null
                    : () => provider.addClientPoint(client),
              );
            },
          ),
        ),
      ],
    );
  }
}
