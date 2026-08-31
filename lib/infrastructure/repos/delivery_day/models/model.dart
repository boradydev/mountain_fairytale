import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable()
class DeliveryDay {
  final int id;
  final DateTime date;
  final int clientsCount;
  final int bottlesCount;
  final int returnsCount;
  final double totalAmount;

  const DeliveryDay({
    required this.id,
    required this.date,
    required this.clientsCount,
    required this.bottlesCount,
    required this.returnsCount,
    required this.totalAmount,
  });

  factory DeliveryDay.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDayFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryDayToJson(this);
}
