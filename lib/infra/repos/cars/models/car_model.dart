import 'package:json_annotation/json_annotation.dart';

part 'car_model.g.dart';

@JsonSerializable()
class Car {
  final int id;
  final String model;
  final String number; // Госномер автомобиля

  const Car({required this.id, required this.model, required this.number});

  factory Car.fromJson(Map<String, dynamic> json) => _$CarFromJson(json);

  Map<String, dynamic> toJson() => _$CarToJson(this);
}
