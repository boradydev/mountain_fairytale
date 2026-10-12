class Product {
  final String id;
  final String name;
  final double basePrice;
  final DateTime createdAt;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.createdAt,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['productId'] as String,
    name: json['name'] as String,
    basePrice: (json['basePrice'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    isActive: json['isActive'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'productId': id,
    'name': name,
    'basePrice': basePrice,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };
}

class CreateProductRequest {
  final String name;
  final double basePrice;

  const CreateProductRequest({required this.name, required this.basePrice});

  Map<String, dynamic> toJson() => {'name': name, 'basePrice': basePrice};
}

class UpdateProductRequest {
  final String? name;
  final double? basePrice;
  final bool? isActive;

  const UpdateProductRequest({this.name, this.basePrice, this.isActive});

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (basePrice != null) 'basePrice': basePrice,
    if (isActive != null) 'isActive': isActive,
  };
}
