// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Client _$ClientFromJson(Map<String, dynamic> json) => Client(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  phone: json['phone'] as String,
  address: json['address'] as String,
  lastDeliveryDate: json['lastDeliveryDate'] == null
      ? null
      : DateTime.parse(json['lastDeliveryDate'] as String),
  lastDeliveryQuantity: (json['lastDeliveryQuantity'] as num?)?.toInt(),
  cooldownUntil: json['cooldownUntil'] == null
      ? null
      : DateTime.parse(json['cooldownUntil'] as String),
  sleepingThresholdDays: (json['sleepingThresholdDays'] as num).toInt(),
  salesRepresentativeId: (json['salesRepresentativeId'] as num?)?.toInt(),
  salesRepresentativeName: json['salesRepresentativeName'] as String?,
  defaultPaymentMethod: json['defaultPaymentMethod'] as String?,
);

Map<String, dynamic> _$ClientToJson(Client instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'phone': instance.phone,
  'address': instance.address,
  'lastDeliveryDate': instance.lastDeliveryDate?.toIso8601String(),
  'lastDeliveryQuantity': instance.lastDeliveryQuantity,
  'cooldownUntil': instance.cooldownUntil?.toIso8601String(),
  'sleepingThresholdDays': instance.sleepingThresholdDays,
  'salesRepresentativeId': instance.salesRepresentativeId,
  'salesRepresentativeName': instance.salesRepresentativeName,
  'defaultPaymentMethod': instance.defaultPaymentMethod,
};

CreateClientRequest _$CreateClientRequestFromJson(Map<String, dynamic> json) =>
    CreateClientRequest(
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      sleepingThresholdDays: (json['sleepingThresholdDays'] as num).toInt(),
      salesRepresentativeId: (json['salesRepresentativeId'] as num?)?.toInt(),
      salesRepresentativeName: json['salesRepresentativeName'] as String?,
      defaultPaymentMethod: json['defaultPaymentMethod'] as String?,
    );

Map<String, dynamic> _$CreateClientRequestToJson(
  CreateClientRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'phone': instance.phone,
  'address': instance.address,
  'sleepingThresholdDays': instance.sleepingThresholdDays,
  'salesRepresentativeId': instance.salesRepresentativeId,
  'salesRepresentativeName': instance.salesRepresentativeName,
  'defaultPaymentMethod': instance.defaultPaymentMethod,
};

UpdateClientRequest _$UpdateClientRequestFromJson(Map<String, dynamic> json) =>
    UpdateClientRequest(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      sleepingThresholdDays: (json['sleepingThresholdDays'] as num?)?.toInt(),
      salesRepresentativeId: (json['salesRepresentativeId'] as num?)?.toInt(),
      salesRepresentativeName: json['salesRepresentativeName'] as String?,
      defaultPaymentMethod: json['defaultPaymentMethod'] as String?,
    );

Map<String, dynamic> _$UpdateClientRequestToJson(
  UpdateClientRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'phone': instance.phone,
  'address': instance.address,
  'sleepingThresholdDays': instance.sleepingThresholdDays,
  'salesRepresentativeId': instance.salesRepresentativeId,
  'salesRepresentativeName': instance.salesRepresentativeName,
  'defaultPaymentMethod': instance.defaultPaymentMethod,
};
