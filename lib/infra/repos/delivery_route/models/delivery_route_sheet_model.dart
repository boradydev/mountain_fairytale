import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/route_point_model.dart';

part 'delivery_route_sheet_model.g.dart';

abstract class RouteDocument {
  int? get id;
  DateTime get date;
  String get title;
}

@JsonSerializable(explicitToJson: true)
class DeliveryRouteSheet implements RouteDocument {
  @override
  final int? id;
  @override
  final DateTime date;
  final String driverName;
  final int carId;
  final String carModelAndNumber;
  final double startMileage;
  final double? endMileage;

  final List<RoutePoint> points;

  @override
  String get title => 'Доставка: $driverName';

  double get grandTotal =>
      points.fold(0.0, (sum, point) => sum + point.totalAmount);

  const DeliveryRouteSheet({
    this.id,
    required this.date,
    required this.driverName,
    required this.carId,
    required this.carModelAndNumber,
    required this.startMileage,
    this.endMileage,
    required this.points,
  });

  DeliveryRouteSheet copyWith({
    int? id,
    DateTime? date,
    String? driverName,
    int? carId,
    String? carModelAndNumber,
    double? startMileage,
    double? endMileage,
    List<RoutePoint>? points,
  }) {
    return DeliveryRouteSheet(
      id: id ?? this.id,
      date: date ?? this.date,
      driverName: driverName ?? this.driverName,
      carId: carId ?? this.carId,
      carModelAndNumber: carModelAndNumber ?? this.carModelAndNumber,
      startMileage: startMileage ?? this.startMileage,
      endMileage: endMileage ?? this.endMileage,
      points: points ?? this.points,
    );
  }

  factory DeliveryRouteSheet.fromJson(Map<String, dynamic> json) =>
      _$DeliveryRouteSheetFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryRouteSheetToJson(this);
}
