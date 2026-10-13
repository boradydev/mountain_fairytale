import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/features/delivery_days/data/delivery_days_product_model.dart';

part 'delivery_days_model.g.dart';

@JsonSerializable()
class DeliveryDay {
  final DateTime plannedDate;
  final int deliveryPointsCount;
  final int pickupPointsCount;
  final List<DeliveryDayProduct> products;
  final double totalAmount;

  const DeliveryDay({
    required this.plannedDate,
    required this.deliveryPointsCount,
    required this.pickupPointsCount,
    required this.products,
    required this.totalAmount,
  });

  factory DeliveryDay.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDayFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryDayToJson(this);
}

class DeliveryDaysPage {
  final List<DeliveryDay> days;
  final int total;
  const DeliveryDaysPage({required this.days, required this.total});
}
