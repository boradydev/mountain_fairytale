import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_route/models/delivery_task_item_model.dart';

part 'route_point_model.g.dart';

@JsonSerializable(explicitToJson: true)
class RoutePoint {
  final int clientId;
  final String clientName;
  final String city;
  final String address;
  final String phone;
  final String paymentMethod; // Форма оплаты (Нал, Безнал, Карта)
  final String salesRepresentative; // Торговый представитель

  // Список товаров/услуг для этой точки
  final List<DeliveryTaskItem> items;

  // Итого по конкретному клиенту
  double get totalAmount => items.fold(0.0, (sum, item) => sum + item.amount);

  const RoutePoint({
    required this.clientId,
    required this.clientName,
    required this.city,
    required this.address,
    required this.phone,
    required this.paymentMethod,
    required this.salesRepresentative,
    required this.items,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) =>
      _$RoutePointFromJson(json);

  Map<String, dynamic> toJson() => _$RoutePointToJson(this);
}
