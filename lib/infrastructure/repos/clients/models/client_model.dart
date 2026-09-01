import 'package:json_annotation/json_annotation.dart';

part 'client_model.g.dart';

@JsonSerializable()
class Client {
  final int id;
  final String name;
  final String phone;
  final String address;
  final DateTime? lastDeliveryDate;
  final int? lastDeliveryQuantity;
  final DateTime? cooldownUntil;

  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.lastDeliveryDate,
    this.lastDeliveryQuantity,
    this.cooldownUntil,
  });

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);

  Map<String, dynamic> toJson() => _$ClientToJson(this);
}
