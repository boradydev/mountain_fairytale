import 'package:mountain_fairytale/infra/repos/delivery_day/models/delivery_day_model.dart';

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
