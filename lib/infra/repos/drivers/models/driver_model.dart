import 'package:json_annotation/json_annotation.dart';

part 'driver_model.g.dart';

@JsonSerializable()
class Driver {
  final int id;
  final String name;

  const Driver({required this.id, required this.name});

  factory Driver.fromJson(Map<String, dynamic> json) => _$DriverFromJson(json);

  Map<String, dynamic> toJson() => _$DriverToJson(this);
}

@JsonSerializable()
class CreateDriverRequest {
  final String name;

  const CreateDriverRequest({required this.name});

  Map<String, dynamic> toJson() => _$CreateDriverRequestToJson(this);
}

@JsonSerializable(includeIfNull: false)
class UpdateDriverRequest {
  final String? name;

  const UpdateDriverRequest({this.name});

  Map<String, dynamic> toJson() => _$UpdateDriverRequestToJson(this);
}
