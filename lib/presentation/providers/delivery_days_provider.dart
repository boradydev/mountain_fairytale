import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/models/model.dart';

enum DeliveryStatus { initial, loading, success, failure }

class DeliveryDaysProvider extends ChangeNotifier {
  final DeliveryDayRepository _repository;

  DeliveryDaysProvider(this._repository);

  static const int _pageSize = 7;

  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<DeliveryDay> _days = const [];

  DeliveryStatus _status = DeliveryStatus.initial;
  String _errorMessage = '';

  List<DeliveryDay> get days => _days;

  DeliveryStatus get status => _status;

  String get errorMessage => _errorMessage;

  bool get isLoading => _status == DeliveryStatus.loading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  bool get hasError => _status == DeliveryStatus.failure;

  bool get isEmpty =>
      _status == DeliveryStatus.success && _days.isEmpty;

  Future<void> fetchDeliveryDays() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;

    if (_days.isEmpty) {
      _status = DeliveryStatus.loading;
    }

    notifyListeners();

    try {
      final newDays = await _repository.getDeliveryDays(
        offset: _offset,
        limit: _pageSize,
      );

      _days = [
        ..._days,
        ...newDays,
      ];

      _offset += newDays.length;

      if (newDays.length < _pageSize) {
        _hasMore = false;
      }

      _status = DeliveryStatus.success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = DeliveryStatus.failure;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}