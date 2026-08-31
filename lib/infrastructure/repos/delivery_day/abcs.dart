import 'package:mountain_fairytale/infrastructure/repos/delivery_day/models/model.dart';

abstract interface class DeliveryDayRepository {
  Future<List<DeliveryDay>> getDeliveryDays();

  Future<DeliveryDay> getDeliveryDay(int id);
}
