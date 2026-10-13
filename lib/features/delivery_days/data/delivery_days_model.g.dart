// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_days_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryDay _$DeliveryDayFromJson(Map<String, dynamic> json) => DeliveryDay(
  plannedDate: DateTime.parse(json['plannedDate'] as String),
  deliveryPointsCount: (json['deliveryPointsCount'] as num).toInt(),
  pickupPointsCount: (json['pickupPointsCount'] as num).toInt(),
  products: (json['products'] as List<dynamic>)
      .map((e) => DeliveryDayProduct.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalAmount: (json['totalAmount'] as num).toDouble(),
);

Map<String, dynamic> _$DeliveryDayToJson(DeliveryDay instance) =>
    <String, dynamic>{
      'plannedDate': instance.plannedDate.toIso8601String(),
      'deliveryPointsCount': instance.deliveryPointsCount,
      'pickupPointsCount': instance.pickupPointsCount,
      'products': instance.products,
      'totalAmount': instance.totalAmount,
    };
