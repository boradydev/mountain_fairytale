// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pickup_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PickupSheet _$PickupSheetFromJson(Map<String, dynamic> json) => PickupSheet(
  id: json['deliveryDocumentId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  isActive: json['isActive'] as bool? ?? true,
  revision: (json['revision'] as num?)?.toInt() ?? 1,
  lastOperationId: json['lastOperationId'] as String?,
  date: DateTime.parse(json['plannedDate'] as String),
  points: (json['points'] as List<dynamic>)
      .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PickupSheetToJson(PickupSheet instance) =>
    <String, dynamic>{
      'deliveryDocumentId': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'isActive': instance.isActive,
      'revision': instance.revision,
      'lastOperationId': instance.lastOperationId,
      'plannedDate': instance.date.toIso8601String(),
      'points': instance.points.map((e) => e.toJson()).toList(),
    };
