// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_day_product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryDayProduct _$DeliveryDayProductFromJson(Map<String, dynamic> json) =>
    DeliveryDayProduct(
      productId: (json['productId'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
    );

Map<String, dynamic> _$DeliveryDayProductToJson(DeliveryDayProduct instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'quantity': instance.quantity,
    };
