// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_representative_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SalesRepresentative _$SalesRepresentativeFromJson(Map<String, dynamic> json) =>
    SalesRepresentative(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      phone: json['phone'] as String,
      commissionPercent: (json['commissionPercent'] as num).toDouble(),
    );

Map<String, dynamic> _$SalesRepresentativeToJson(
  SalesRepresentative instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'phone': instance.phone,
  'commissionPercent': instance.commissionPercent,
};

CreateSalesRepresentativeRequest _$CreateSalesRepresentativeRequestFromJson(
  Map<String, dynamic> json,
) => CreateSalesRepresentativeRequest(
  name: json['name'] as String,
  phone: json['phone'] as String,
  commissionPercent: (json['commissionPercent'] as num).toDouble(),
);

Map<String, dynamic> _$CreateSalesRepresentativeRequestToJson(
  CreateSalesRepresentativeRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'phone': instance.phone,
  'commissionPercent': instance.commissionPercent,
};

UpdateSalesRepresentativeRequest _$UpdateSalesRepresentativeRequestFromJson(
  Map<String, dynamic> json,
) => UpdateSalesRepresentativeRequest(
  name: json['name'] as String?,
  phone: json['phone'] as String?,
  commissionPercent: (json['commissionPercent'] as num?)?.toDouble(),
);

Map<String, dynamic> _$UpdateSalesRepresentativeRequestToJson(
  UpdateSalesRepresentativeRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'phone': instance.phone,
  'commissionPercent': instance.commissionPercent,
};
