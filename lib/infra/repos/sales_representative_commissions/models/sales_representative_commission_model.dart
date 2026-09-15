import 'package:json_annotation/json_annotation.dart';

part 'sales_representative_commission_model.g.dart';

/// Готовые данные о вознаграждении торгового представителя.
///
/// Все расчёты выполняются на стороне backend/repository.
/// Flutter только отображает полученные значения.
@JsonSerializable()
class SalesRepresentativeCommission {
  final int salesRepresentativeId;
  final String salesRepresentativeName;
  final double commissionPercent;

  /// Количество клиентов, по которым рассчитано вознаграждение.
  final int clientsCount;

  /// Оборот за выбранный период.
  final double totalSalesAmount;

  /// Готовая сумма вознаграждения.
  final double commissionAmount;

  const SalesRepresentativeCommission({
    required this.salesRepresentativeId,
    required this.salesRepresentativeName,
    required this.commissionPercent,
    required this.clientsCount,
    required this.totalSalesAmount,
    required this.commissionAmount,
  });

  factory SalesRepresentativeCommission.fromJson(Map<String, dynamic> json) =>
      _$SalesRepresentativeCommissionFromJson(json);

  Map<String, dynamic> toJson() => _$SalesRepresentativeCommissionToJson(this);
}
