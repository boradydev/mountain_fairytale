import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_history/delivery_history_abcs.dart';
import 'package:mountain_fairytale/shared/utils/date_range_limits.dart';

class DeliveryHistoryProvider extends SafeChangeNotifier {
  final DeliveryHistoryRepository _repository;
  final DateTime Function() _now;
  DeliveryHistoryProvider(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _dateRange = _defaultRange();
  }

  static const pageSize = 50;
  bool clientsMode = true;
  String documentType = 'all';
  List<ClientDelivery> _deliveries = [];
  List<ClientDelivery> get deliveries => List.unmodifiable(_deliveries);
  int _offset = 0;
  bool get isEmpty => clientsMode ? _deliveries.isEmpty : _documents.isEmpty;

  Future<void> setClientsMode(bool value) async {
    if (clientsMode == value) return;
    clientsMode = value;
    await refresh();
  }

  Future<void> setDocumentType(String value) async {
    if (documentType == value) return;
    documentType = value;
    await refresh();
  }

  late DateTimeRange _dateRange;
  DateTimeRange get dateRange => _dateRange;
  String _search = '';
  String get search => _search;
  bool _includeCancelled = false;
  bool get includeCancelled => _includeCancelled;
  List<HistoryDocument> _documents = [];
  List<HistoryDocument> get documents => List.unmodifiable(_documents);
  int _total = 0;
  int get total => _total;
  bool _loading = false;
  bool get loading => _loading;
  bool _loaded = false;
  bool get loaded => _loaded;
  String? _error;
  String? get error => _error;
  bool get hasMore => _offset < _total;
  int _generation = 0;

  DateTimeRange _defaultRange() {
    final today = DateUtils.dateOnly(_now());
    return DateTimeRange(
      start: DateTime(today.year, today.month, today.day - 29),
      end: today,
    );
  }

  Future<void> setDateRange(DateTimeRange range) async {
    final normalized = DateTimeRange(
      start: DateUtils.dateOnly(range.start),
      end: DateUtils.dateOnly(range.end),
    );
    if (!isDateRangeWithinMonths(normalized, 12)) {
      throw ArgumentError('Период не может превышать 12 месяцев');
    }
    _dateRange = normalized;
    await refresh();
  }

  Future<void> setSearch(String value) async {
    if (_search == value.trim()) return;
    _search = value.trim();
    await refresh();
  }

  Future<void> setIncludeCancelled(bool value) async {
    if (value == _includeCancelled) return;
    _includeCancelled = value;
    await refresh();
  }

  Future<void> refresh() async {
    _generation++;
    _documents = [];
    _deliveries = [];
    _offset = 0;
    _loaded = false;
    _total = 0;
    await _fetch(append: false);
  }

  Future<void> loadMore() async {
    if (_loading || !hasMore) return;
    await _fetch(append: true);
  }

  Future<void> _fetch({required bool append}) async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (clientsMode) {
        final page = await _repository.getClientHistory(
          dateFrom: _dateRange.start,
          dateTo: _dateRange.end,
          search: _search,
          offset: append ? _offset : 0,
          limit: pageSize,
        );
        if (generation != _generation) return;
        _offset = (append ? _offset : 0) + page.deliveries.length;
        _deliveries = {
          for (final point in [..._deliveries, ...page.deliveries])
            point.pointId: point,
        }.values.toList();
        _total = page.total;
      } else {
        final page = await _repository.getHistory(
          dateFrom: _dateRange.start,
          dateTo: _dateRange.end,
          search: '',
          includeCancelled: _includeCancelled,
          documentType: documentType,
          offset: append ? _offset : 0,
          limit: pageSize,
        );
        if (generation != _generation) return;
        _offset = (append ? _offset : 0) + page.documents.length;
        _documents = {
          for (final doc in [..._documents, ...page.documents]) doc.id: doc,
        }.values.toList();
        _total = page.total;
      }
      _loaded = true;
    } catch (_) {
      if (generation != _generation) return;
      _error = 'Не удалось загрузить историю. Повторите запрос.';
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
