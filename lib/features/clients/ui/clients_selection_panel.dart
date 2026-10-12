import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';

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
  Client? _selectedClient;
  bool _busy = false;

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

  Future<void> _showClientEditor({Client? client}) async {
    final saved = await showClientDialog(
      context,
      client: client,
      orderProvider: widget.provider,
    );
    if (!mounted) return;
    if (saved != null) {
      setState(() => _selectedClient = saved);
      widget.provider.syncClientPoint(saved);
      if (saved.isActive) widget.provider.addClientPoint(saved);
    }
    await _search();
  }

  Future<void> _selectClient(Client client) async {
    if (_busy) return;
    setState(() {
      _selectedClient = client;
      _busy = true;
    });
    try {
      var selected = client;
      if (!client.isActive) {
        final confirmed = await ConfirmDialog.show(
          context,
          title: 'Активировать и добавить клиента?',
          content:
              '«${client.name}» снова станет доступен для новых маршрутов.',
          confirmText: 'Активировать и добавить',
        );
        if (!confirmed || !mounted) return;
        final provider = context.read<ClientsProvider>();
        if (!await provider.setClientActive(client.id, true) || !mounted)
          return;
        selected = provider.lastSavedClient!;
        await _search();
      }
      if (!mounted) return;
      setState(() => _selectedClient = selected);
      widget.provider.addClientPoint(selected);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          AppDropdown<Client>(
            label: 'Клиент *',
            items: filteredClients,
            value: _selectedClient,
            enabled: !_busy,
            showInactiveToggle: true,
            includeInactive: _includeInactive,
            onIncludeInactiveChanged: (value) {
              setState(() => _includeInactive = value);
              _scheduleSearch();
            },
            showEdit: true,
            showAdd: true,
            editBeforeAdd: true,
            onEdit: _selectedClient == null
                ? null
                : () => _showClientEditor(client: _selectedClient),
            onAdd: () => _showClientEditor(),
            onChanged: (value) {
              if (value != null) _selectClient(value);
            },
            field: TextField(
              controller: _clientSearchController,
              enabled: !_busy,
              onChanged: (_) => _scheduleSearch(),
              decoration: InputDecoration(
                hintText: 'Имя, адрес или телефон',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
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
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                  selected: _selectedClient?.id == client.id,
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
                  onTap: _busy ? null : () => _selectClient(client),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
