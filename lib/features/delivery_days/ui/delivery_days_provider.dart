import 'dart:math';

import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';

enum DeliveryStatus { initial, loading, success, failure }

class DeliveryDaysProvider extends SafeChangeNotifier {
  final DeliveryDayRepository repository;
  DeliveryDaysProvider(this.repository);
  static const int _pageSize = 7;
  List<DeliveryDay> _days = const [];
  DeliveryStatus _status = DeliveryStatus.initial;
  String _errorMessage = '';
  bool _isLoadingMore = false;
  int _total = 0;
  int _version = 0;
  List<DeliveryDay> get days => _days;
  DeliveryStatus get status => _status;
  String get errorMessage => _errorMessage;
  int get total => _total;
  bool get isLoading => _status == DeliveryStatus.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore =>
      _status == DeliveryStatus.initial || _days.length < _total;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get isEmpty => _status == DeliveryStatus.success && _days.isEmpty;
  Future<void> refreshDeliveryDays() => _load(refresh: true);
  Future<void> fetchDeliveryDays() async {
    if (_isLoadingMore || (_status == DeliveryStatus.success && !hasMore)) {
      return;
    }
    await _load(refresh: _days.isEmpty);
  }

  Future<void> _load({required bool refresh}) async {
    final version = ++_version;
    final offset = refresh ? 0 : _days.length;
    final limit = refresh ? max(_pageSize, _days.length) : _pageSize;
    _isLoadingMore = true;
    _errorMessage = '';
    if (_days.isEmpty) _status = DeliveryStatus.loading;
    notifyListeners();
    try {
      final page = await repository.getDeliveryDays(
        offset: offset,
        limit: limit,
      );
      if (version != _version) return;
      _days = refresh ? page.days : [..._days, ...page.days];
      _total = page.total;
      _status = DeliveryStatus.success;
    } catch (_) {
      if (version != _version) return;
      _errorMessage = 'Не удалось загрузить дни доставки. Повторите запрос.';
      if (_days.isEmpty) _status = DeliveryStatus.failure;
    } finally {
      if (version == _version) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _version++;
    super.dispose();
  }
}
