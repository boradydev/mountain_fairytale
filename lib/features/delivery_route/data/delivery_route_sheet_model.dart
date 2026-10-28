import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';

part 'delivery_route_sheet_model.g.dart';

abstract class RouteDocument {
  int get revision;
  String? get lastOperationId;
  String? get id;
  DateTime? get createdAt;
  bool get isActive;
  DateTime get date;
  String get title;
}

@JsonSerializable(explicitToJson: true)
class DeliveryRouteSheet implements RouteDocument {
  @override
  @JsonKey(name: 'deliveryDocumentId')
  final String? id;
  @override
  final DateTime? createdAt;
  @override
  @JsonKey(defaultValue: true)
  final bool isActive;
  @override
  @JsonKey(defaultValue: 1)
  final int revision;
  @override
  final String? lastOperationId;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? saveOperationId;
  @override
  @JsonKey(name: 'plannedDate')
  final DateTime date;
  final String driverName;
  final String? driverId;
  final String carId;
  final String carModelAndNumber;
  final double startMileage;
  final double? endMileage;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool carChangeConfirmed;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double? previousCarMileage;

  double? get distance =>
      endMileage == null ? null : endMileage! - startMileage;

  final List<RoutePoint> points;

  @override
  String get title => 'Доставка: $driverName';

  double get grandTotal =>
      points.fold(0, (sum, point) => sum + point.totalCents) / 100;
  Map<String, dynamic> toRequestJson() => {
    if (id != null) 'expectedRevision': revision,
    if (id != null && saveOperationId != null) 'operationId': saveOperationId,
    if (id == null && saveOperationId != null)
      'creationRequestId': saveOperationId,
    'plannedDate': date.toIso8601String().substring(0, 10),
    'driverId': driverId,
    'carId': carId,
    'startMileage': startMileage,
    'endMileage': endMileage,
    if (id != null && carChangeConfirmed) 'carChangeConfirmed': true,
    if (id != null && previousCarMileage != null)
      'previousCarMileage': previousCarMileage,
    'points': points
        .map((point) => point.toRequestJson(creating: id == null))
        .toList(),
  };

  const DeliveryRouteSheet({
    this.id,
    this.createdAt,
    this.isActive = true,
    this.revision = 1,
    this.lastOperationId,
    this.saveOperationId,
    required this.date,
    required this.driverName,
    this.driverId,
    required this.carId,
    required this.carModelAndNumber,
    required this.startMileage,
    this.endMileage,
    this.carChangeConfirmed = false,
    this.previousCarMileage,
    required this.points,
  });

  DeliveryRouteSheet copyWith({
    String? id,
    DateTime? date,
    String? driverName,
    String? driverId,
    String? carId,
    String? carModelAndNumber,
    double? startMileage,
    double? endMileage,
    List<RoutePoint>? points,
  }) {
    return DeliveryRouteSheet(
      id: id ?? this.id,
      createdAt: createdAt,
      isActive: isActive,
      revision: revision,
      lastOperationId: lastOperationId,
      saveOperationId: saveOperationId,
      date: date ?? this.date,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
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
