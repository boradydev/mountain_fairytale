// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pickup_sheet_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PickupSheet _$PickupSheetFromJson(Map<String, dynamic> json) => PickupSheet(
  id: (json['id'] as num?)?.toInt(),
  date: DateTime.parse(json['date'] as String),
  points: (json['points'] as List<dynamic>)
      .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PickupSheetToJson(PickupSheet instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'points': instance.points.map((e) => e.toJson()).toList(),
    };
