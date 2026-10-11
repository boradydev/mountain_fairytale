// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cars_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Car _$CarFromJson(Map<String, dynamic> json) => Car(
  id: json['carId'] as String,
  model: json['model'] as String,
  number: json['number'] as String,
  currentMileage: (json['currentMileage'] as num).toDouble(),
  isActive: json['isActive'] as bool? ?? true,
);

Map<String, dynamic> _$CarToJson(Car instance) => <String, dynamic>{
  'carId': instance.id,
  'model': instance.model,
  'number': instance.number,
  'currentMileage': instance.currentMileage,
  'isActive': instance.isActive,
};

Map<String, dynamic> _$CreateCarRequestToJson(CreateCarRequest instance) =>
    <String, dynamic>{
      'model': instance.model,
      'number': instance.number,
      'currentMileage': instance.currentMileage,
    };

Map<String, dynamic> _$UpdateCarRequestToJson(UpdateCarRequest instance) =>
    <String, dynamic>{
      'model': ?instance.model,
      'number': ?instance.number,
      'currentMileage': ?instance.currentMileage,
      'isActive': ?instance.isActive,
    };
