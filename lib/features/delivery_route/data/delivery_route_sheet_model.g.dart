// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_route_sheet_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryRouteSheet _$DeliveryRouteSheetFromJson(Map<String, dynamic> json) =>
    DeliveryRouteSheet(
      id: (json['id'] as num?)?.toInt(),
      date: DateTime.parse(json['date'] as String),
      driverName: json['driverName'] as String,
      carId: (json['carId'] as num).toInt(),
      carModelAndNumber: json['carModelAndNumber'] as String,
      startMileage: (json['startMileage'] as num).toDouble(),
      endMileage: (json['endMileage'] as num?)?.toDouble(),
      points: (json['points'] as List<dynamic>)
          .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DeliveryRouteSheetToJson(DeliveryRouteSheet instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'driverName': instance.driverName,
      'carId': instance.carId,
      'carModelAndNumber': instance.carModelAndNumber,
      'startMileage': instance.startMileage,
      'endMileage': instance.endMileage,
      'points': instance.points.map((e) => e.toJson()).toList(),
    };
