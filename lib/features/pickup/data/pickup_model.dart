import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';

part 'pickup_model.g.dart';

@JsonSerializable(explicitToJson: true)
class PickupSheet implements RouteDocument {
  @override
  @JsonKey(name: 'deliveryDocumentId')
  final String? id;
  @override
  final DateTime? createdAt;
  @override
  @JsonKey(defaultValue: true)
  final bool isActive;
  @override
  @JsonKey(name: 'plannedDate')
  final DateTime date;
  final List<RoutePoint> points;

  @override
  String get title => 'Самовывоз';

  double get grandTotal =>
      points.fold(0, (sum, point) => sum + point.totalCents) / 100;
  Map<String, dynamic> toRequestJson() => {
    'plannedDate': date.toIso8601String().substring(0, 10),

    'points': points
        .map((point) => point.toRequestJson(creating: id == null))
        .toList(),
  };

  const PickupSheet({
    this.id,
    this.createdAt,
    this.isActive = true,
    required this.date,
    required this.points,
  });

  PickupSheet copyWith({
    String? id,
    DateTime? date,
    List<RoutePoint>? points,
  }) {
    return PickupSheet(
      id: id ?? this.id,
      createdAt: createdAt,
      isActive: isActive,
      date: date ?? this.date,
      points: points ?? this.points,
    );
  }

  factory PickupSheet.fromJson(Map<String, dynamic> json) =>
      _$PickupSheetFromJson(json);

  Map<String, dynamic> toJson() => _$PickupSheetToJson(this);
}
