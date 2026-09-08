import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/route_point_model.dart';

part 'delivery_route_sheet_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeliveryRouteSheet {
  final int? id; // null при создании, присваивается на "сервере"
  final DateTime date;
  final String driverName;
  final int carId;
  final String
  carModelAndNumber; // Для быстрого отображения (например: "Газель А123ББ")
  final double startMileage;
  final double? endMileage; // null, пока водитель не вернулся

  // Все точки (клиенты) в этом выезде
  final List<RoutePoint> points;

  // Общий итог по всему маршрутному листу
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

  factory DeliveryRouteSheet.fromJson(Map<String, dynamic> json) =>
      _$DeliveryRouteSheetFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryRouteSheetToJson(this);
}
