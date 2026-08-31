import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/models/model.dart';

enum DeliveryStatus { initial, loading, success, failure }

class DeliveryDaysProvider extends ChangeNotifier {
  final DeliveryDayRepository _repository;

  DeliveryDaysProvider(this._repository);

  static const int _pageSize = 7;

  List<DeliveryDay> _allDays = const [];
  List<DeliveryDay> _days = const [];

  DeliveryStatus _status = DeliveryStatus.initial;
  String _errorMessage = '';

  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<DeliveryDay> get days => _days;

  DeliveryStatus get status => _status;

  String get errorMessage => _errorMessage;

  bool get isLoading => _status == DeliveryStatus.loading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  bool get hasError => _status == DeliveryStatus.failure;

  bool get isEmpty => _status == DeliveryStatus.success && _days.isEmpty;

  Future<void> fetchDeliveryDays({bool isRefresh = false}) async {
    // Не допускаем повторную загрузку первой страницы
    // или загрузку следующей страницы одновременно.
    if (_isLoadingMore || _status == DeliveryStatus.loading) {
      return;
    }

    try {
      if (isRefresh) {
        _status = DeliveryStatus.loading;
        _errorMessage = '';
        _hasMore = true;
        _days = const [];

        notifyListeners();

        _allDays = await _repository.getDeliveryDays();

        _loadNextPage();

        _status = DeliveryStatus.success;
        notifyListeners();

        return;
      }

      // Если это обычная загрузка следующей страницы
      if (!_hasMore) {
        return;
      }

      _isLoadingMore = true;
      notifyListeners();

      // Небольшая задержка только для демонстрации поведения пагинации.
      // Потом её можно убрать, когда появится реальный API.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      _loadNextPage();

      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _errorMessage = e.toString();
      _status = DeliveryStatus.failure;

      notifyListeners();
    }
  }

  void _loadNextPage() {
    final start = _days.length;

    if (start >= _allDays.length) {
      _hasMore = false;
      return;
    }

    final end = (start + _pageSize).clamp(0, _allDays.length);

    _days = [
      ..._days,
      ..._allDays.sublist(start, end),
    ];

    if (end >= _allDays.length) {
      _hasMore = false;
    }
  }
}