// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_day_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryDay _$DeliveryDayFromJson(Map<String, dynamic> json) => DeliveryDay(
  id: (json['id'] as num).toInt(),
  date: DateTime.parse(json['date'] as String),
  clientsCount: (json['clientsCount'] as num).toInt(),
  returnsCount: (json['returnsCount'] as num).toInt(),
  products: (json['products'] as List<dynamic>)
      .map((e) => DeliveryDayProduct.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalAmount: (json['totalAmount'] as num).toDouble(),
);

Map<String, dynamic> _$DeliveryDayToJson(DeliveryDay instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'clientsCount': instance.clientsCount,
      'returnsCount': instance.returnsCount,
      'products': instance.products,
      'totalAmount': instance.totalAmount,
    };
