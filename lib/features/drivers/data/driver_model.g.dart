// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Driver _$DriverFromJson(Map<String, dynamic> json) =>
    Driver(id: (json['id'] as num).toInt(), name: json['name'] as String);

Map<String, dynamic> _$DriverToJson(Driver instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};

CreateDriverRequest _$CreateDriverRequestFromJson(Map<String, dynamic> json) =>
    CreateDriverRequest(name: json['name'] as String);

Map<String, dynamic> _$CreateDriverRequestToJson(
  CreateDriverRequest instance,
) => <String, dynamic>{'name': instance.name};

UpdateDriverRequest _$UpdateDriverRequestFromJson(Map<String, dynamic> json) =>
    UpdateDriverRequest(name: json['name'] as String?);

Map<String, dynamic> _$UpdateDriverRequestToJson(
  UpdateDriverRequest instance,
) => <String, dynamic>{'name': ?instance.name};
