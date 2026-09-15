// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_day_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryDay _$DeliveryDayFromJson(Map<String, dynamic> json) => DeliveryDay(
  id: (json['id'] as num).toInt(),
  date: DateTime.parse(json['date'] as String),
  clientsCount: (json['clientsCount'] as num).toInt(),
  bottlesCount: (json['bottlesCount'] as num).toInt(),
  returnsCount: (json['returnsCount'] as num).toInt(),
  glassesCount: (json['glassesCount'] as num).toInt(),
  waterCoolerCount: (json['waterCoolerCount'] as num).toInt(),
  coolerRepairCount: (json['coolerRepairCount'] as num).toInt(),
  totalAmount: (json['totalAmount'] as num).toDouble(),
);

Map<String, dynamic> _$DeliveryDayToJson(DeliveryDay instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'clientsCount': instance.clientsCount,
      'bottlesCount': instance.bottlesCount,
      'returnsCount': instance.returnsCount,
      'glassesCount': instance.glassesCount,
      'waterCoolerCount': instance.waterCoolerCount,
      'coolerRepairCount': instance.coolerRepairCount,
      'totalAmount': instance.totalAmount,
    };
