import 'package:json_annotation/json_annotation.dart';

part 'delivery_day_product_model.g.dart';

@JsonSerializable()
class DeliveryDayProduct {
  final int productId;
  final int quantity;

  const DeliveryDayProduct({
    required this.productId,
    required this.quantity,
  });

  factory DeliveryDayProduct.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDayProductFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryDayProductToJson(this);
}
