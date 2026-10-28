// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_route_sheet_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryRouteSheet _$DeliveryRouteSheetFromJson(Map<String, dynamic> json) =>
    DeliveryRouteSheet(
      id: json['deliveryDocumentId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      lastOperationId: json['lastOperationId'] as String?,
      date: DateTime.parse(json['plannedDate'] as String),
      driverName: json['driverName'] as String,
      driverId: json['driverId'] as String?,
      carId: json['carId'] as String,
      carModelAndNumber: json['carModelAndNumber'] as String,
      startMileage: (json['startMileage'] as num).toDouble(),
      endMileage: (json['endMileage'] as num?)?.toDouble(),
      points: (json['points'] as List<dynamic>)
          .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DeliveryRouteSheetToJson(DeliveryRouteSheet instance) =>
    <String, dynamic>{
      'deliveryDocumentId': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'isActive': instance.isActive,
      'revision': instance.revision,
      'lastOperationId': instance.lastOperationId,
      'plannedDate': instance.date.toIso8601String(),
      'driverName': instance.driverName,
      'driverId': instance.driverId,
      'carId': instance.carId,
      'carModelAndNumber': instance.carModelAndNumber,
      'startMileage': instance.startMileage,
      'endMileage': instance.endMileage,
      'points': instance.points.map((e) => e.toJson()).toList(),
    };
