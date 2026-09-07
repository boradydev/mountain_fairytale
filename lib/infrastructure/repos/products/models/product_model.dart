import 'package:json_annotation/json_annotation.dart';

part 'product_model.g.dart';

@JsonSerializable()
class Product {
  final int id;
  final String name; // Например: "Вода 19л", "Стаканы", "Ремонт кулера"
  final double basePrice; // Базовая цена

  const Product({
    required this.id,
    required this.name,
    required this.basePrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
