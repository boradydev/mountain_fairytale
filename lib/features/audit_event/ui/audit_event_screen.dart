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

class _AuditLogScreenState extends State<AuditLogScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  Timer? _pollTimer;
  bool _visible = false;
  bool _appActive = true;
  bool _pollInFlight = false;
  bool get _canPoll => mounted && _visible && _appActive;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _appActive = state == null || state == AppLifecycleState.resumed;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible == visible) return;
    _visible = visible;
    _updatePolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    _updatePolling();
  }

  void _updatePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_canPoll) return;
    if (context.read<AuditLogProvider>().supportsUpdates) {
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
  }

  Future<void> _poll() async {
    if (!_canPoll || _pollInFlight || (_searchTimer?.isActive ?? false)) return;
    _pollInFlight = true;
    final provider = context.read<AuditLogProvider>();
    try {
      if (provider.status == AuditLogStatus.initial ||
          provider.status == AuditLogStatus.failure) {
        await provider.fetchEvents();
      } else {
        await provider.checkForUpdates(shouldContinue: () => _canPoll);
        if (_canPoll &&
            !provider.hasMoreUpdates &&
            (!_scrollController.hasClients || _scrollController.offset <= 8)) {
          provider.showPendingEvents();
        }
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _showNewEvents() {
    context.read<AuditLogProvider>().showPendingEvents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _scrollController.jumpTo(0);
    });
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
      if (mounted && provider.events.isNotEmpty) _showNewEvents();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
        if (provider.hasPendingEvents)
          Padding(
            padding: const EdgeInsets.all(8),
            child: AppSecondaryButton(
              text: 'Есть новые события — показать',
              onPressed: _showNewEvents,
            ),
          ),
        if (provider.updatesError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              provider.updatesError,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
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
                      findItemIndexCallback: (key) {
                        if (key is! ValueKey<String>) return null;
                        final index = groups.indexWhere(
                          (group) => group.operationId == key.value,
                        );
                        return index < 0 ? null : index;
                      },
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
