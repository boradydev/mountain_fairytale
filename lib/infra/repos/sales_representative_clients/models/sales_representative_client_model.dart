import 'package:json_annotation/json_annotation.dart';

part 'sales_representative_client_model.g.dart';

@JsonSerializable()
class SalesRepresentativeClient {
  final int clientId;
  final String clientName;
  final String phone;
  final int ordersCount;
  final double totalSalesAmount;
  final DateTime? lastOrderDate;
  final double commissionAmount;

  const SalesRepresentativeClient({
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.ordersCount,
    required this.totalSalesAmount,
    this.lastOrderDate,
    required this.commissionAmount,
  });

  factory SalesRepresentativeClient.fromJson(Map<String, dynamic> json) =>
      _$SalesRepresentativeClientFromJson(json);

  Map<String, dynamic> toJson() => _$SalesRepresentativeClientToJson(this);
}
