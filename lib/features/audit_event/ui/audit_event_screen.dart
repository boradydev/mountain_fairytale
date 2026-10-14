import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_provider.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_row.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<AuditLogProvider>();
        if (provider.status == AuditLogStatus.initial) provider.fetchEvents();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 200) {
      context.read<AuditLogProvider>().fetchEvents();
    }
  }

  void _search(String value) {
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<AuditLogProvider>().searchEvents(value);
    });
  }

  Future<void> _refresh() async {
    _searchTimer?.cancel();
    final provider = context.read<AuditLogProvider>();
    if (provider.search != _searchController.text.trim()) {
      await provider.searchEvents(_searchController.text);
    } else {
      await provider.refreshEvents();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditLogProvider>();
    final groups = provider.operations;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _search,
                  maxLength: 500,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Поиск по журналу...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : AppIconButton(
                            icon: Icons.clear,
                            tooltip: 'Очистить поиск',
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppIconButton(
                icon: Icons.refresh,
                tooltip: 'Обновить журнал',
                onPressed: _refresh,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (provider.isLoadingMore && provider.events.isNotEmpty)
          const LinearProgressIndicator(),
        if (provider.hasError)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(provider.errorMessage)),
                AppSecondaryButton(
                  text: 'Повторить',
                  onPressed: provider.fetchEvents,
                ),
              ],
            ),
          ),
        Expanded(
          child: switch (provider.status) {
            AuditLogStatus.initial || AuditLogStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            AuditLogStatus.failure => const Center(
              child: Text('Не удалось загрузить журнал'),
            ),
            AuditLogStatus.success =>
              groups.isEmpty
                  ? const Center(child: Text('События не найдены'))
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: groups.length,
                      separatorBuilder: (context, _) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      itemBuilder: (_, index) {
                        final group = groups[index];
                        return AuditOperationRow(
                          key: ValueKey(group.operationId),
                          operation: group,
                        );
                      },
                    ),
          },
        ),
      ],
    );
  }
}
