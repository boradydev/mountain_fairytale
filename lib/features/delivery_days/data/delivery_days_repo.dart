import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';

class ApiDeliveryRepository implements DeliveryDayRepository {
  final DeliveryDataSource dataSource;

  ApiDeliveryRepository(this.dataSource);

  @override
  Future<List<DeliveryDay>> getDeliveryDays({
    required int offset,
    required int limit,
  }) async {
    final json = await dataSource.getDeliveryDays(
      offset: offset,
      limit: limit,
    );

    return json.map(DeliveryDay.fromJson).toList();
  }

  @override
  Future<DeliveryDay> getDeliveryDay(int id) async {
    final json = await dataSource.getDeliveryDay(id);

    return DeliveryDay.fromJson(json);
  }
}
