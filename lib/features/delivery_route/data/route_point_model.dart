import 'package:json_annotation/json_annotation.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';

part 'route_point_model.g.dart';

@JsonSerializable(explicitToJson: true)
class RoutePoint {
  final String? pointId;
  @JsonKey(defaultValue: true)
  final bool isDelivered;
  @JsonKey(defaultValue: '')
  final String nonDeliveryReason;
  final int position;
  final String? salesRepresentativeId;
  final String? clientId;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? localId;
  String get viewId => clientId ?? pointId ?? localId!;
  final String clientName;
  @JsonKey(defaultValue: '')
  final String city;
  final String address;
  final String? clientAddress;
  @JsonKey(defaultValue: '')
  final String deliveryDetails;
  final String phone;
  @JsonKey(name: 'defaultPaymentMethodId')
  final String? paymentMethodId;
  @JsonKey(name: 'defaultPaymentMethodName')
  final String? paymentMethod; // Форма оплаты (Нал, Безнал, Карта)
  @JsonKey(name: 'paymentMethodId')
  final String? documentPaymentMethodId;
  @JsonKey(name: 'paymentMethodName')
  final String? documentPaymentMethodName;
  @JsonKey(name: 'salesRepresentativeName', defaultValue: 'Нет представителя')
  final String salesRepresentative; // Торговый представитель

  // Список товаров/услуг для этой точки
  final List<DeliveryTaskItem> items;

  // Итого по конкретному клиенту

  int get totalCents => items.fold(0, (sum, item) => sum + item.amountCents);
  double get totalAmount => totalCents / 100;
  int get accountedTotalCents => isDelivered ? totalCents : 0;
  RoutePoint copyWith({
    List<DeliveryTaskItem>? items,
    bool? isDelivered,
    String? nonDeliveryReason,
  }) => RoutePoint(
    pointId: pointId,
    isDelivered: isDelivered ?? this.isDelivered,
    nonDeliveryReason: nonDeliveryReason ?? this.nonDeliveryReason,
    localId: localId,
    position: position,
    clientId: clientId,
    clientName: clientName,
    city: city,
    address: address,
    clientAddress: clientAddress,
    deliveryDetails: deliveryDetails,
    phone: phone,
    paymentMethodId: paymentMethodId,
    paymentMethod: paymentMethod,
    documentPaymentMethodId: documentPaymentMethodId,
    documentPaymentMethodName: documentPaymentMethodName,
    salesRepresentativeId: salesRepresentativeId,
    salesRepresentative: salesRepresentative,
    items: items ?? this.items,
  );
  Map<String, dynamic> toRequestJson({required bool creating}) => {
    if (!creating && pointId != null) 'pointId': pointId,
    'clientId': clientId,
    'isDelivered': isDelivered,
    'nonDeliveryReason': nonDeliveryReason,
    'paymentMethodId': documentPaymentMethodId,
    'items': items.map((item) => item.toRequestJson()).toList(),
  };

  const RoutePoint({
    this.pointId,
    this.isDelivered = true,
    this.nonDeliveryReason = '',
    this.localId,
    this.position = 0,
    this.salesRepresentativeId,
    required this.clientId,
    required this.clientName,
    this.city = '',
    required this.address,
    this.clientAddress,
    this.deliveryDetails = '',
    required this.phone,
    this.paymentMethod,
    this.paymentMethodId,
    this.documentPaymentMethodId,
    this.documentPaymentMethodName,
    required this.salesRepresentative,
    required this.items,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) =>
      _$RoutePointFromJson({...json, 'clientId': json['clientId']?.toString()});

  Map<String, dynamic> toJson() => _$RoutePointToJson(this);
}
