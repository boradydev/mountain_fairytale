// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_point_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutePoint _$RoutePointFromJson(Map<String, dynamic> json) => RoutePoint(
  clientId: (json['clientId'] as num).toInt(),
  clientName: json['clientName'] as String,
  city: json['city'] as String,
  address: json['address'] as String,
  phone: json['phone'] as String,
  paymentMethod: json['paymentMethod'] as String?,
  salesRepresentative: json['salesRepresentative'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => DeliveryTaskItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RoutePointToJson(RoutePoint instance) =>
    <String, dynamic>{
      'clientId': instance.clientId,
      'clientName': instance.clientName,
      'city': instance.city,
      'address': instance.address,
      'phone': instance.phone,
      'paymentMethod': instance.paymentMethod,
      'salesRepresentative': instance.salesRepresentative,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };
