import 'package:json_annotation/json_annotation.dart';

part 'delivery_task_item_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeliveryTaskItem {
  final int productId;
  final String productName;
  final int quantity;
  final double price;

  // Вычисляемое поле суммы для удобства на UI
  double get amount => quantity * price;

  const DeliveryTaskItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory DeliveryTaskItem.fromJson(Map<String, dynamic> json) =>
      _$DeliveryTaskItemFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryTaskItemToJson(this);
}
