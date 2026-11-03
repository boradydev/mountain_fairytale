// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_point_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutePoint _$RoutePointFromJson(Map<String, dynamic> json) => RoutePoint(
  pointId: json['pointId'] as String?,
  position: (json['position'] as num?)?.toInt() ?? 0,
  salesRepresentativeId: json['salesRepresentativeId'] as String?,
  clientId: json['clientId'] as String?,
  clientName: json['clientName'] as String,
  city: json['city'] as String? ?? '',
  address: json['address'] as String,
  clientAddress: json['clientAddress'] as String?,
  deliveryDetails: json['deliveryDetails'] as String? ?? '',
  phone: json['phone'] as String,
  paymentMethod: json['defaultPaymentMethodName'] as String?,
  paymentMethodId: json['defaultPaymentMethodId'] as String?,
  documentPaymentMethodId: json['paymentMethodId'] as String?,
  documentPaymentMethodName: json['paymentMethodName'] as String?,
  salesRepresentative:
      json['salesRepresentativeName'] as String? ?? 'Нет представителя',
  items: (json['items'] as List<dynamic>)
      .map((e) => DeliveryTaskItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RoutePointToJson(RoutePoint instance) =>
    <String, dynamic>{
      'pointId': instance.pointId,
      'position': instance.position,
      'salesRepresentativeId': instance.salesRepresentativeId,
      'clientId': instance.clientId,
      'clientName': instance.clientName,
      'city': instance.city,
      'address': instance.address,
      'clientAddress': instance.clientAddress,
      'deliveryDetails': instance.deliveryDetails,
      'phone': instance.phone,
      'defaultPaymentMethodId': instance.paymentMethodId,
      'defaultPaymentMethodName': instance.paymentMethod,
      'paymentMethodId': instance.documentPaymentMethodId,
      'paymentMethodName': instance.documentPaymentMethodName,
      'salesRepresentativeName': instance.salesRepresentative,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };
