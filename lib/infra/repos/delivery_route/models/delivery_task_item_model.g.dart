// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_task_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryTaskItem _$DeliveryTaskItemFromJson(Map<String, dynamic> json) =>
    DeliveryTaskItem(
      productId: (json['productId'] as num).toInt(),
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
    );

Map<String, dynamic> _$DeliveryTaskItemToJson(DeliveryTaskItem instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'price': instance.price,
    };
