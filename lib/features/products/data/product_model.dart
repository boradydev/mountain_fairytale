class Product {
  final String id;
  final String name;
  final double basePrice;
  final bool isFreePrice;
  final DateTime createdAt;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.basePrice,
    this.isFreePrice = false,
    required this.createdAt,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['productId'] as String,
    name: json['name'] as String,
    basePrice: (json['basePrice'] as num).toDouble(),
    isFreePrice: json['isFreePrice'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isActive: json['isActive'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'productId': id,
    'name': name,
    'basePrice': basePrice,
    'isFreePrice': isFreePrice,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };
}

class CreateProductRequest {
  final String name;
  final double basePrice;
  final bool isFreePrice;

  const CreateProductRequest({
    required this.name,
    required this.basePrice,
    this.isFreePrice = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'basePrice': isFreePrice ? 0 : basePrice,
    'isFreePrice': isFreePrice,
  };
}

class UpdateProductRequest {
  final String? name;
  final double? basePrice;
  final bool? isFreePrice;
  final bool? isActive;

  const UpdateProductRequest({
    this.name,
    this.basePrice,
    this.isFreePrice,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (basePrice != null || isFreePrice == true)
      'basePrice': isFreePrice == true ? 0 : basePrice,
    if (isFreePrice != null) 'isFreePrice': isFreePrice,
    if (isActive != null) 'isActive': isActive,
  };
}
