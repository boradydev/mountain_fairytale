import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
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
    if (!_canPoll || _pollInFlight) return;
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

  Future<void> _filterSelected(String selection) async {
    final provider = context.read<AuditLogProvider>();
    final filters = provider.filters;
    AuditFilters updated;
    if (selection == 'dates') {
      final from = filters.dateFrom?.toLocal();
      final to = filters.dateTo?.toLocal();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100, 12, 31),
        initialDateRange: from != null && to != null
            ? DateTimeRange(
                start: from,
                end: DateTime(to.year, to.month, to.day - 1),
              )
            : null,
        helpText: 'Период событий',
        saveText: 'Применить',
        cancelText: 'Отмена',
        fieldStartLabelText: 'От',
        fieldEndLabelText: 'До',
      );
      if (!mounted || range == null) return;
      updated = AuditFilters(
        action: filters.action,
        dateFrom: DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        ),
        dateTo: DateTime(range.end.year, range.end.month, range.end.day + 1),
      );
    } else if (selection == 'allDates') {
      updated = AuditFilters(action: filters.action);
    } else if (selection == 'reset') {
      updated = const AuditFilters();
    } else {
      final code = selection.substring('action:'.length);
      updated = AuditFilters(
        action: code == 'all' ? null : AuditAction.fromCode(code),
        dateFrom: filters.dateFrom,
        dateTo: filters.dateTo,
      );
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await provider.setFilters(updated);
  }

  String _periodLabel(AuditFilters filters) {
    final from = filters.dateFrom?.toLocal();
    final to = filters.dateTo?.toLocal();
    if (from == null || to == null) return 'Все даты';
    final format = DateFormat('dd.MM.yyyy');
    return '${format.format(from)} — ${format.format(DateTime(to.year, to.month, to.day - 1))}';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditLogProvider>();
    final groups = provider.operations;
    final filters = provider.filters;
    final filterLabel =
        '${filters.action == null ? 'Все действия' : auditActionLabel(filters.action!)} · ${_periodLabel(filters)}';
    return Column(
      children: [
        SizedBox(
          height: 76,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Фильтры: $filterLabel',
                          icon: Icon(
                            filters.isEmpty
                                ? Icons.filter_list
                                : Icons.filter_alt,
                            color: filters.isEmpty
                                ? null
                                : Theme.of(context).colorScheme.primary,
                          ),
                          onSelected: _filterSelected,
                          itemBuilder: (_) => [
                            const PopupMenuItem<String>(
                              enabled: false,
                              child: Text('Тип действия'),
                            ),
                            CheckedPopupMenuItem<String>(
                              value: 'action:all',
                              checked: filters.action == null,
                              child: const Text('Все действия'),
                            ),
                            for (final action in AuditAction.values)
                              CheckedPopupMenuItem<String>(
                                value:
                                    'action:${action == AuditAction.passwordChanged ? 'password_changed' : action.name}',
                                checked: filters.action == action,
                                child: Text(auditActionLabel(action)),
                              ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'dates',
                              child: Text('Период: ${_periodLabel(filters)}'),
                            ),
                            if (filters.dateFrom != null ||
                                filters.dateTo != null)
                              const PopupMenuItem<String>(
                                value: 'allDates',
                                child: Text('Все даты'),
                              ),
                            if (!filters.isEmpty)
                              const PopupMenuItem<String>(
                                value: 'reset',
                                child: Text('Сбросить фильтры'),
                              ),
                          ],
                        ),
                        if (constraints.maxWidth >= 650) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tooltip(
                              message: filterLabel,
                              child: Text(
                                filterLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                        if (provider.hasError ||
                            provider.updatesError.isNotEmpty)
                          AppIconButton(
                            icon: Icons.error_outline,
                            tooltip: provider.hasError
                                ? provider.errorMessage
                                : provider.updatesError,
                            onPressed: provider.hasError
                                ? provider.fetchEvents
                                : _poll,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Visibility(
                              visible: provider.hasPendingEvents,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AppSecondaryButton(
                                  text: 'Есть новые события — показать',
                                  onPressed: _showNewEvents,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 2,
                child: provider.isLoadingMore && provider.events.isNotEmpty
                    ? const LinearProgressIndicator(minHeight: 2)
                    : const SizedBox.shrink(),
              ),
              const Divider(height: 1),
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
