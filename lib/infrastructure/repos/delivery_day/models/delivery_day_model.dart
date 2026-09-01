import 'package:json_annotation/json_annotation.dart';

part 'delivery_day_model.g.dart';

@JsonSerializable()
class DeliveryDay {
  final int id;
  final DateTime date;
  final int clientsCount;
  final int bottlesCount;
  final int returnsCount;
  final int glassesCount;
  final int waterCoolerCount;
  final int coolerRepairCount;
  final double totalAmount;

  const DeliveryDay({
    required this.id,
    required this.date,
    required this.clientsCount,
    required this.bottlesCount,
    required this.returnsCount,
    required this.glassesCount,
    required this.waterCoolerCount,
    required this.coolerRepairCount,
    required this.totalAmount,
  });

  factory DeliveryDay.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDayFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryDayToJson(this);
}
