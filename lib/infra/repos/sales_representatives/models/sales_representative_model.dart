import 'package:json_annotation/json_annotation.dart';

part 'sales_representative_model.g.dart';

/// Модель сущности.
@JsonSerializable()
class SalesRepresentative {
  final int id;
  final String name;
  final String phone;
  final double commissionPercent;

  const SalesRepresentative({
    required this.id,
    required this.name,
    required this.phone,
    required this.commissionPercent,
  });

  factory SalesRepresentative.fromJson(Map<String, dynamic> json) =>
      _$SalesRepresentativeFromJson(json);

  Map<String, dynamic> toJson() => _$SalesRepresentativeToJson(this);
}

/// DTO для создания сущности (POST).
@JsonSerializable()
class CreateSalesRepresentativeRequest {
  final String name;
  final String phone;
  final double commissionPercent;

  const CreateSalesRepresentativeRequest({
    required this.name,
    required this.phone,
    required this.commissionPercent,
  });

  Map<String, dynamic> toJson() =>
      _$CreateSalesRepresentativeRequestToJson(this);
}

/// DTO для частичного редактирования сущности (PATCH).
@JsonSerializable(includeIfNull: true)
class UpdateSalesRepresentativeRequest {
  final String? name;
  final String? phone;
  final double? commissionPercent;

  const UpdateSalesRepresentativeRequest({
    this.name,
    this.phone,
    this.commissionPercent,
  });

  Map<String, dynamic> toJson() =>
      _$UpdateSalesRepresentativeRequestToJson(this);
}
