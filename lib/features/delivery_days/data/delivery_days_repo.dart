import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';

class ApiDeliveryRepository implements DeliveryDayRepository {
  final DeliveryDataSource dataSource;
  ApiDeliveryRepository(this.dataSource);
  @override
  Future<DeliveryDaysPage> getDeliveryDays({
    required int offset,
    required int limit,
  }) async {
    final response = await dataSource.getDeliveryDays(
      offset: offset,
      limit: limit,
    );
    final data = response['data'] as Map;
    return DeliveryDaysPage(
      days: (data['deliveryDays'] as List)
          .map(
            (row) =>
                DeliveryDay.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      total: (response['total'] as num).toInt(),
    );
  }

  @override
  Future<List<RouteDocument>> getDayDocuments(
    DateTime date, {
    bool includeCancelled = false,
  }) async {
    final rows = await dataSource.getDayDocuments(
      date,
      includeCancelled: includeCancelled,
    );
    return rows
        .map<RouteDocument>(
          (row) => switch (row['documentType']) {
            'deliveryRouteSheet' => DeliveryRouteSheet.fromJson(row),
            'pickupSheet' => PickupSheet.fromJson(row),
            _ => throw const FormatException('Неизвестный тип документа'),
          },
        )
        .toList();
  }
}
