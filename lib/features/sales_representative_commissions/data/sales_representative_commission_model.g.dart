// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_representative_commission_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SalesRepresentativeCommissionReport
_$SalesRepresentativeCommissionReportFromJson(Map<String, dynamic> json) =>
    SalesRepresentativeCommissionReport(
      commissions: (json['commissions'] as List<dynamic>)
          .map(
            (e) => SalesRepresentativeCommission.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      totalCommissionAmount: (json['totalCommissionAmount'] as num).toDouble(),
    );

Map<String, dynamic> _$SalesRepresentativeCommissionReportToJson(
  SalesRepresentativeCommissionReport instance,
) => <String, dynamic>{
  'commissions': instance.commissions,
  'totalCommissionAmount': instance.totalCommissionAmount,
};

SalesRepresentativeCommission _$SalesRepresentativeCommissionFromJson(
  Map<String, dynamic> json,
) => SalesRepresentativeCommission(
  salesRepresentativeId: (json['salesRepresentativeId'] as num).toInt(),
  salesRepresentativeName: json['salesRepresentativeName'] as String,
  commissionPercent: (json['commissionPercent'] as num).toDouble(),
  clientsCount: (json['clientsCount'] as num).toInt(),
  totalSalesAmount: (json['totalSalesAmount'] as num).toDouble(),
  commissionAmount: (json['commissionAmount'] as num).toDouble(),
);

Map<String, dynamic> _$SalesRepresentativeCommissionToJson(
  SalesRepresentativeCommission instance,
) => <String, dynamic>{
  'salesRepresentativeId': instance.salesRepresentativeId,
  'salesRepresentativeName': instance.salesRepresentativeName,
  'commissionPercent': instance.commissionPercent,
  'clientsCount': instance.clientsCount,
  'totalSalesAmount': instance.totalSalesAmount,
  'commissionAmount': instance.commissionAmount,
};
