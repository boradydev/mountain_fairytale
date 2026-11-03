import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/delivery_history_provider.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/history_document_card.dart';
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
  Timer? _debounce;
  bool _visible = false;
  bool _searchInitialized = false;
  bool _opening = false;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'История доставок и самовывозов',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Клиент, адрес или телефон',
                  hintText: 'Найти документы с покупками клиента',
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppSecondaryButton(
                    text:
                        '${date.format(provider.dateRange.start)} — ${date.format(provider.dateRange.end)}',
                    icon: Icons.date_range,
                    onPressed: () => _selectPeriod(provider),
                  ),
                  LabeledCheckboxToggle(
                    label: 'Показывать отменённые',
                    value: provider.includeCancelled,
                    onChanged: provider.setIncludeCancelled,
                  ),
                  AppSecondaryButton(
                    text: 'Сбросить',
                    onPressed: () {
                      _debounce?.cancel();
                      _search.clear();
                      unawaited(provider.resetFilters());
                    },
                  ),
                  AppIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Обновить историю',
                    onPressed: provider.refresh,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (provider.loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            key: const PageStorageKey('delivery-history-list'),
            children: [
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(provider.error!),
                      const SizedBox(height: 8),
                      AppSecondaryButton(
                        text: 'Повторить',
                        onPressed: provider.loading
                            ? null
                            : provider.documents.isEmpty
                            ? provider.refresh
                            : provider.loadMore,
                      ),
                    ],
                  ),
                ),
              if (!provider.loading &&
                  provider.error == null &&
                  provider.documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('За выбранный период документы не найдены.'),
                ),
              if (provider.documents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text('Документов: ${provider.total}'),
                ),
              for (final document in provider.documents)
                HistoryDocumentCard(
                  document: document,
                  onOpen: () => _open(document),
                ),
              if (provider.hasMore)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: AppSecondaryButton(
                      text: 'Показать ещё',
                      onPressed: provider.loading ? null : provider.loadMore,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
