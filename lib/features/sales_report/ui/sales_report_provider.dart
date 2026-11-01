import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/sales_report/data/sales_report_model.dart';
import 'package:mountain_fairytale/features/sales_report/sales_report_abcs.dart';

enum SalesReportStatus { initial, loading, success, failure }

class SalesReportProvider extends SafeChangeNotifier {
  final SalesReportRepository _repository;
  SalesReportProvider(this._repository, {DateTime? now})
    : _dateRange = _initialRange(now ?? DateTime.now());

  DateTimeRange _dateRange;
  DateTimeRange get dateRange => _dateRange;

  SalesReport? _report;
  SalesReport? get report => _report;

  SalesReportStatus _status = SalesReportStatus.initial;
  SalesReportStatus get status => _status;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  int _requestVersion = 0;

  static DateTimeRange _initialRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: DateTime(now.year, now.month), end: today);
  }

  Future<void> ensureLoaded() async {
    if (_status == SalesReportStatus.initial) await refresh();
  }

  Future<void> setDateRange(DateTimeRange range) async {
    _dateRange = DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day),
    );
    _report = null;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final version = ++_requestVersion;
    _status = SalesReportStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final report = await _repository.getSalesReport(
        dateFrom: _dateRange.start,
        dateTo: _dateRange.end,
      );
      if (version != _requestVersion) return;
      _report = report;
      _status = SalesReportStatus.success;
    } catch (_) {
      if (version != _requestVersion) return;
      _errorMessage = 'Не удалось загрузить отчет. Повторите запрос.';
      _status = SalesReportStatus.failure;
    } finally {
      if (version == _requestVersion) notifyListeners();
    }
  }

  @override
  void dispose() {
    _requestVersion++;
    super.dispose();
  }
}
