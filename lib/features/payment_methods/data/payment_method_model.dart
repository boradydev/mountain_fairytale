class PaymentMethod {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isActive;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isActive,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['paymentMethodId'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isActive: json['isActive'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'paymentMethodId': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };
}

class CreatePaymentMethodRequest {
  final String name;

  const CreatePaymentMethodRequest({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}

class UpdatePaymentMethodRequest {
  final String? name;
  final bool? isActive;

  const UpdatePaymentMethodRequest({this.name, this.isActive});

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (isActive != null) 'isActive': isActive,
  };
}
