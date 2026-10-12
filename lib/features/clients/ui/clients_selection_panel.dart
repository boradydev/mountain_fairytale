import 'dart:async';

import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_dialog.dart';
import 'package:provider/provider.dart';

class ClientSelectionPanel extends StatefulWidget {
  final OrderPointsProvider provider;

  const ClientSelectionPanel({super.key, required this.provider});

  @override
  State<ClientSelectionPanel> createState() => _ClientSelectionPanelState();
}

class _ClientSelectionPanelState extends State<ClientSelectionPanel> {
  final TextEditingController _clientSearchController = TextEditingController();

  Timer? _debounce;
  int _searchVersion = 0;
  bool _searching = false;
  bool _includeInactive = false;
  String? _searchError;
  List<Client>? _searchResults;

  void _scheduleSearch() {
    _debounce?.cancel();
    _searchVersion++;
    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
    });
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final version = ++_searchVersion;
    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
    });
    try {
      final rows = await context.read<ClientsProvider>().searchClients(
        _clientSearchController.text.trim(),
        includeDeactivated: _includeInactive,
      );
      if (mounted && version == _searchVersion) {
        setState(() => _searchResults = rows);
      }
    } catch (_) {
      if (mounted && version == _searchVersion) {
        setState(
          () =>
              _searchError = 'Не удалось загрузить клиентов. Повторите поиск.',
        );
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchVersion++;
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _showAddClientDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const ClientDialog(),
    );
    if (mounted) await _search();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final clientProvider = context.watch<ClientsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final filteredClients = _searchResults ?? clientProvider.clients;

    // ДОБАВЛЕНО: Обернули всю панель в Padding 16, как в RouteMetaPanel
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
              // Сдвигаем иконку чуть правее, чтобы компенсировать внутренний отступ кнопки
              AppIconButton(
                onPressed: () => _showAddClientDialog(context),
                icon: Icons.add,
                tooltip: 'Добавить клиента',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clientSearchController,
            onChanged: (_) => _scheduleSearch(),
            decoration: InputDecoration(
              hintText: 'Имя, адрес или телефон',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _clientSearchController.text.isEmpty
                  ? null
                  : AppIconButton(
                      icon: Icons.clear,
                      tooltip: 'Очистить поиск',
                      onPressed: () {
                        _clientSearchController.clear();
                        _scheduleSearch();
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Показать деактивированных'),
            value: _includeInactive,
            onChanged: (value) {
              setState(() => _includeInactive = value ?? false);
              _scheduleSearch();
            },
          ),
          if (_searching) const LinearProgressIndicator(),
          if (_searchError != null)
            Text(_searchError!, style: TextStyle(color: colorScheme.error)),
          if (!_searching && _searchError == null && filteredClients.isEmpty)
            const Text('Клиенты не найдены'),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(right: 12.0),
              // ИСПРАВЛЕНО: Убрали внутренние отступы списка
              itemCount: filteredClients.length,
              itemBuilder: (context, idx) {
                final client = filteredClients[idx];

                final isAlreadyAdded = provider.points.any(
                  (point) => point.clientId == client.id,
                );

                return ListTile(
                  // ИСПРАВЛЕНО: Убираем боковые отступы ListTile, чтобы выровнять по границам TextField
                  contentPadding: EdgeInsets.zero,
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
                            if (mounted) await _search();
                          },
                  ),
                  title: Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isAlreadyAdded
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${client.address}${client.isActive ? '' : ' — Деактивирован'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isAlreadyAdded
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  trailing: !client.isActive
                      ? const Icon(Icons.archive_outlined)
                      : isAlreadyAdded
                      ? const Icon(Icons.check_circle, color: Colors.grey)
                      : const Icon(Icons.add_circle, color: Colors.green),
                  dense: true,
                  onTap: isAlreadyAdded || !client.isActive
                      ? null
                      : () => provider.addClientPoint(client),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
