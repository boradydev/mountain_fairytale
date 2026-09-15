// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Car _$CarFromJson(Map<String, dynamic> json) => Car(
  id: (json['id'] as num).toInt(),
  model: json['model'] as String,
  number: json['number'] as String,
  currentMileage: (json['currentMileage'] as num).toDouble(),
);

Map<String, dynamic> _$CarToJson(Car instance) => <String, dynamic>{
  'id': instance.id,
  'model': instance.model,
  'number': instance.number,
  'currentMileage': instance.currentMileage,
};

CreateCarRequest _$CreateCarRequestFromJson(Map<String, dynamic> json) =>
    CreateCarRequest(
      model: json['model'] as String,
      number: json['number'] as String,
    );

Map<String, dynamic> _$CreateCarRequestToJson(CreateCarRequest instance) =>
    <String, dynamic>{'model': instance.model, 'number': instance.number};

UpdateCarRequest _$UpdateCarRequestFromJson(Map<String, dynamic> json) =>
    UpdateCarRequest(
      model: json['model'] as String?,
      number: json['number'] as String?,
      currentMileage: (json['currentMileage'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$UpdateCarRequestToJson(UpdateCarRequest instance) =>
    <String, dynamic>{
      'model': ?instance.model,
      'number': ?instance.number,
      'currentMileage': ?instance.currentMileage,
    };
