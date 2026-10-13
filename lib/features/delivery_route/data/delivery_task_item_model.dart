import 'package:json_annotation/json_annotation.dart';

import 'package:mountain_fairytale/features/delivery_route/data/document_money.dart';

part 'delivery_task_item_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeliveryTaskItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;

  // Вычисляемое поле суммы для удобства на UI
  int get amountCents => lineAmountCents(quantity, price);
  double get amount => amountCents / 100;
  Map<String, dynamic> toRequestJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'price': price,
  };

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
