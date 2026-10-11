import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';

part 'pickup_model.g.dart';

@JsonSerializable(explicitToJson: true)
class PickupSheet implements RouteDocument {
  @override
  final int? id;
  @override
  final DateTime date;
  final List<RoutePoint> points;

  @override
  String get title => 'Самовывоз';

  double get grandTotal =>
      points.fold(0.0, (sum, point) => sum + point.totalAmount);

  const PickupSheet({
    this.id,
    required this.date,
    required this.points,
  });

  PickupSheet copyWith({
    int? id,
    DateTime? date,
    List<RoutePoint>? points,
  }) {
    return PickupSheet(
      id: id ?? this.id,
      date: date ?? this.date,
      points: points ?? this.points,
    );
  }

  factory PickupSheet.fromJson(Map<String, dynamic> json) =>
      _$PickupSheetFromJson(json);

  Map<String, dynamic> toJson() => _$PickupSheetToJson(this);
}
