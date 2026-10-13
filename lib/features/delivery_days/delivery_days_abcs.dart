import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';

abstract interface class DeliveryDataSource {
  Future<Map<String, dynamic>> getDeliveryDays({
    required int offset,
    required int limit,
  });

  Future<List<Map<String, dynamic>>> getDayDocuments(
    DateTime date, {
    bool includeCancelled = false,
  });
}

abstract interface class DeliveryDayRepository {
  Future<DeliveryDaysPage> getDeliveryDays({
    required int offset,
    required int limit,
  });

  Future<List<RouteDocument>> getDayDocuments(
    DateTime date, {
    bool includeCancelled = false,
  });
}
