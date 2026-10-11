// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) =>
    PaymentMethod(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$PaymentMethodToJson(PaymentMethod instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

CreatePaymentMethodRequest _$CreatePaymentMethodRequestFromJson(
  Map<String, dynamic> json,
) => CreatePaymentMethodRequest(name: json['name'] as String);

Map<String, dynamic> _$CreatePaymentMethodRequestToJson(
  CreatePaymentMethodRequest instance,
) => <String, dynamic>{'name': instance.name};

UpdatePaymentMethodRequest _$UpdatePaymentMethodRequestFromJson(
  Map<String, dynamic> json,
) => UpdatePaymentMethodRequest(name: json['name'] as String?);

Map<String, dynamic> _$UpdatePaymentMethodRequestToJson(
  UpdatePaymentMethodRequest instance,
) => <String, dynamic>{'name': instance.name};
