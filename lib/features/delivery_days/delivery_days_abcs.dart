import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';

abstract interface class DeliveryDataSource {
  Future<List<Map<String, dynamic>>> getDeliveryDays({
    required int offset,
    required int limit,
  });

  Future<Map<String, dynamic>> getDeliveryDay(int id);
}

abstract interface class DeliveryDayRepository {
  Future<List<DeliveryDay>> getDeliveryDays({
    required int offset,
    required int limit,
  });

  Future<DeliveryDay> getDeliveryDay(int id);
}
