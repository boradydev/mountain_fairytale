import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/models/delivery_day_product_model.dart';

part 'delivery_day_model.g.dart';

@JsonSerializable()
class DeliveryDay {
  final int id;
  final DateTime date;
  final int clientsCount;
  final int returnsCount;
  final List<DeliveryDayProduct> products;
  final double totalAmount;

  const DeliveryDay({
    required this.id,
    required this.date,
    required this.clientsCount,
    required this.returnsCount,
    required this.products,
    required this.totalAmount,
  });

  factory DeliveryDay.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDayFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryDayToJson(this);
}
