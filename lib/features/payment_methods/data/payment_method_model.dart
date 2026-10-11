import 'package:json_annotation/json_annotation.dart';

part 'payment_method_model.g.dart';

/// Модель сущности.
@JsonSerializable()
class PaymentMethod {
  final int id;
  final String name;

  const PaymentMethod({required this.id, required this.name});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentMethodToJson(this);
}

/// DTO для создания сущности (POST).
@JsonSerializable()
class CreatePaymentMethodRequest {
  final String name;

  const CreatePaymentMethodRequest({required this.name});

  Map<String, dynamic> toJson() => _$CreatePaymentMethodRequestToJson(this);
}

/// DTO для частичного редактирования сущности (PATCH).
@JsonSerializable(includeIfNull: true)
class UpdatePaymentMethodRequest {
  final String? name;

  const UpdatePaymentMethodRequest({this.name});

  Map<String, dynamic> toJson() => _$UpdatePaymentMethodRequestToJson(this);
}
