import 'package:json_annotation/json_annotation.dart';

part 'delivery_days_product_model.g.dart';

@JsonSerializable()
class DeliveryDayProduct {
  final String productId;
  final String productName;
  final int quantity;

  const DeliveryDayProduct({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory DeliveryDayProduct.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDayProductFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryDayProductToJson(this);
}
