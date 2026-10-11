import 'package:json_annotation/json_annotation.dart';

part 'cars_model.g.dart';

@JsonSerializable()
class Car {
  @JsonKey(name: 'carId')
  final String id;
  final String model;
  final String number; // Госномер автомобиля
  @JsonKey(defaultValue: true)
  final bool isActive;

  /// Текущий пробег автомобиля.
  ///
  /// Обновляется автоматически при завершении маршрутного листа.
  final double currentMileage;

  const Car({
    required this.id,
    required this.model,
    required this.number,
    required this.currentMileage,
    this.isActive = true,
  });

  factory Car.fromJson(Map<String, dynamic> json) => _$CarFromJson(json);

  Map<String, dynamic> toJson() => _$CarToJson(this);
}

@JsonSerializable(createFactory: false)
class CreateCarRequest {
  final String model;
  final String number;
  final double? currentMileage;

  const CreateCarRequest({
    required this.model,
    required this.number,
    this.currentMileage = 0,
  });

  Map<String, dynamic> toJson() => _$CreateCarRequestToJson(this);
}

@JsonSerializable(createFactory: false, includeIfNull: false)
class UpdateCarRequest {
  final String? model;
  final String? number;
  final double? currentMileage;
  final bool? isActive;

  const UpdateCarRequest({
    this.model,
    this.number,
    this.currentMileage,
    this.isActive,
  });

  Map<String, dynamic> toJson() => _$UpdateCarRequestToJson(this);
}
