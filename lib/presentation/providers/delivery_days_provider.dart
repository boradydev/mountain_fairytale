import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/models/model.dart';

enum DeliveryStatus { initial, loading, success, failure }

class DeliveryDaysProvider extends ChangeNotifier {
  final DeliveryDayRepository _repository;

  DeliveryDaysProvider(this._repository);

  // Приватное состояние по вашему стилю
  List<DeliveryDay> _days = const [];
  DeliveryStatus _status = DeliveryStatus.initial;
  String _errorMessage = '';

  // Публичные геттеры для чтения
  List<DeliveryDay> get days => _days;

  DeliveryStatus get status => _status;

  String get errorMessage => _errorMessage;

  // Вычисляемые свойства (Computed properties) в вашем стиле
  bool get isLoading => _status == DeliveryStatus.loading;

  bool get hasError => _status == DeliveryStatus.failure;

  bool get isEmpty => _status == DeliveryStatus.success && _days.isEmpty;

  Future<void> fetchDeliveryDays() async {
    _status = DeliveryStatus.loading;
    notifyListeners();

    try {
      _days = await _repository.getDeliveryDays();
      _status = DeliveryStatus.success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = DeliveryStatus.failure;
    }

    // Строгий вызов в самом конце метода
    notifyListeners();
  }
}
