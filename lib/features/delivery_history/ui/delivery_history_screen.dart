import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/delivery_history_provider.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/history_document_card.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/client_delivery_card.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_screen.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_screen.dart';
import 'package:mountain_fairytale/shared/utils/app_date_range_picker.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});
  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _visible = false;
  bool _searchInitialized = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadNearEnd);
  }

  void _loadNearEnd() {
    if (!_scroll.hasClients || !mounted) return;
    final provider = context.read<DeliveryHistoryProvider>();
    if (_scroll.position.extentAfter < 500 && provider.error == null) {
      unawaited(provider.loadMore());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_searchInitialized) {
      _search.text = context.read<DeliveryHistoryProvider>().search;
      _searchInitialized = true;
    }
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) {
          unawaited(context.read<DeliveryHistoryProvider>().refresh());
        }
      });
    }
    _visible = visible;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        unawaited(context.read<DeliveryHistoryProvider>().setSearch(value));
      }
    });
  }

  Future<void> _selectPeriod(DeliveryHistoryProvider provider) async {
    final range = await showAppDateRangePicker(
      context,
      initialDateRange: provider.dateRange,
      helpText: 'Период истории — до 12 месяцев',
      maxRangeMonths: 12,
      showReset: true,
    );
    if (mounted && range != null) await provider.setDateRange(range);
  }

  Future<void> _open(HistoryDocument document) async {
    if (_opening) return;
    _opening = true;
    final provider = context.read<DeliveryHistoryProvider>();
    final days = context.read<DeliveryDaysProvider?>();
    void changed() {
      unawaited(provider.refresh());
      if (days != null) unawaited(days.refreshDeliveryDays());
    }

    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => document.isPickup
              ? PickupConstructorScreen(
                  existingPickupId: document.id,
                  initialDate: document.plannedDate,
                  onDocumentChanged: changed,
                )
              : RouteConstructorScreen(
                  existingRouteId: document.id,
                  initialDate: document.plannedDate,
                  onDocumentChanged: changed,
                ),
        ),
      );
      if (mounted) await provider.refresh();
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryHistoryProvider>();
    final date = DateFormat('dd.MM.yyyy');
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Material(
            key: const ValueKey('delivery-history-toolbar-surface'),
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScaler = MediaQuery.textScalerOf(context);
                  final compactWidth = constraints.maxWidth < 300;
                  final controlHeight = math.max(
                    72 * textScaler.scale(1),
                    textScaler.scale(14) * 1.4 + 24,
                  );
                  final mode = SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Клиенты'),
                        icon: Icon(Icons.people_outline),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Документы'),
                        icon: Icon(Icons.description_outlined),
                      ),
                    ],
                    selected: {provider.clientsMode},
                    onSelectionChanged: (values) =>
                        provider.setClientsMode(values.single),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: colors.primary,
                      selectedForegroundColor: colors.onPrimary,
                    ),
                  );
                  final period = AppSecondaryButton(
                    text:
                        '${date.format(provider.dateRange.start)} — ${date.format(provider.dateRange.end)}',
                    icon: Icons.date_range,
                    onPressed: () => _selectPeriod(provider),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [mode, period],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: colors.outlineVariant),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              controlHeight +
                              (compactWidth ? 30 : 12) * textScaler.scale(1),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: provider.clientsMode
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  child: TextField(
                                    controller: _search,
                                    maxLength: 500,
                                    decoration: InputDecoration(
                                      labelText: 'Клиент, адрес, уточнение или телефон',
                                      border: const OutlineInputBorder(),
                                      counterText: '',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: AppIconButton(
                                        icon: Icons.clear,
                                        tooltip: 'Очистить поиск',
                                        onPressed: () {
                                          _debounce?.cancel();
                                          _search.clear();
                                          unawaited(provider.setSearch(''));
                                        },
                                      ),
                                    ),
                                    onChanged: _searchChanged,
                                    onSubmitted: (value) {
                                      _debounce?.cancel();
                                      unawaited(provider.setSearch(value));
                                    },
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SegmentedButton<String>(
                                      showSelectedIcon: false,
                                      segments: const [
                                        ButtonSegment(
                                          value: 'all',
                                          label: Text('Все'),
                                        ),
                                        ButtonSegment(
                                          value: 'delivery_route_sheet',
                                          label: Text('Доставки'),
                                        ),
                                        ButtonSegment(
                                          value: 'pickup_sheet',
                                          label: Text('Самовывозы'),
                                        ),
                                      ],
                                      selected: {provider.documentType},
                                      onSelectionChanged: (values) =>
                                          provider.setDocumentType(
                                            values.single,
                                          ),
                                      style: SegmentedButton.styleFrom(
                                        selectedBackgroundColor: colors.primary,
                                        selectedForegroundColor:
                                            colors.onPrimary,
                                      ),
                                    ),
                                    LabeledCheckboxToggle(
                                      label: 'Отменённые',
                                      value: provider.includeCancelled,
                                      onChanged: provider.setIncludeCancelled,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(
          height: 4,
          child: provider.loading ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _loadNearEnd(),
              );
              return false;
            },
            child: ListView.builder(
              controller: _scroll,
              key: const PageStorageKey('delivery-history-list'),
              itemCount:
                  (provider.clientsMode
                      ? provider.deliveries.length
                      : provider.documents.length) +
                  2,
              itemBuilder: (context, index) {
                final count = provider.clientsMode
                    ? provider.deliveries.length
                    : provider.documents.length;
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      !provider.isEmpty
                          ? '${provider.clientsMode ? 'Доставок' : 'Документов'}: ${provider.total}'
                          : !provider.loading && provider.error == null
                          ? 'За выбранный период записи не найдены.'
                          : '',
                    ),
                  );
                }
                if (index == count + 1) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (provider.error != null) ...[
                          Text(provider.error!),
                          AppSecondaryButton(
                            text: 'Повторить',
                            onPressed: provider.loading
                                ? null
                                : provider.isEmpty
                                ? provider.refresh
                                : provider.loadMore,
                          ),
                        ],
                        if (provider.loading && !provider.isEmpty)
                          const CircularProgressIndicator(),
                      ],
                    ),
                  );
                }
                if (provider.clientsMode) {
                  final delivery = provider.deliveries[index - 1];
                  return ClientDeliveryCard(
                    key: ValueKey(delivery.pointId),
                    delivery: delivery,
                    onOpen: () => _open(delivery.document),
                  );
                }
                final document = provider.documents[index - 1];
                return HistoryDocumentCard(
                  key: ValueKey(document.id),
                  document: document,
                  onOpen: () => _open(document),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
