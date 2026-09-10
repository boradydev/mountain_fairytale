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

@JsonSerializable()
class CreateCarRequest {
  final String model;
  final String number;

  const CreateCarRequest({
    required this.model,
    required this.number,
  });

  Map<String, dynamic> toJson() => _$CreateCarRequestToJson(this);
}

@JsonSerializable(includeIfNull: false)
class UpdateCarRequest {
  final String? model;
  final String? number;

  const UpdateCarRequest({
    this.model,
    this.number,
  });

  Map<String, dynamic> toJson() => _$UpdateCarRequestToJson(this);
}