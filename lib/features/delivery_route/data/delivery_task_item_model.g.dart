// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_task_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryTaskItem _$DeliveryTaskItemFromJson(Map<String, dynamic> json) =>
    DeliveryTaskItem(
      itemId: json['itemId'] as String?,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      isFreePrice: json['isFreePrice'] as bool? ?? false,
      driverNote: json['driverNote'] as String? ?? '',
    );

Map<String, dynamic> _$DeliveryTaskItemToJson(DeliveryTaskItem instance) =>
    <String, dynamic>{
      'itemId': instance.itemId,
      'productId': instance.productId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'price': instance.price,
      'isFreePrice': instance.isFreePrice,
      'driverNote': instance.driverNote,
    };
