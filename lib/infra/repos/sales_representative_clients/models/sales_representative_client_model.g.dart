// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_representative_client_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SalesRepresentativeClient _$SalesRepresentativeClientFromJson(
  Map<String, dynamic> json,
) => SalesRepresentativeClient(
  clientId: (json['clientId'] as num).toInt(),
  clientName: json['clientName'] as String,
  phone: json['phone'] as String,
  ordersCount: (json['ordersCount'] as num).toInt(),
  totalSalesAmount: (json['totalSalesAmount'] as num).toDouble(),
  lastOrderDate: json['lastOrderDate'] == null
      ? null
      : DateTime.parse(json['lastOrderDate'] as String),
  commissionAmount: (json['commissionAmount'] as num).toDouble(),
);

Map<String, dynamic> _$SalesRepresentativeClientToJson(
  SalesRepresentativeClient instance,
) => <String, dynamic>{
  'clientId': instance.clientId,
  'clientName': instance.clientName,
  'phone': instance.phone,
  'ordersCount': instance.ordersCount,
  'totalSalesAmount': instance.totalSalesAmount,
  'lastOrderDate': instance.lastOrderDate?.toIso8601String(),
  'commissionAmount': instance.commissionAmount,
};
