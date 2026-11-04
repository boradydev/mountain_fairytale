import 'package:json_annotation/json_annotation.dart';

import 'package:mountain_fairytale/features/delivery_route/data/document_money.dart';

part 'delivery_task_item_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeliveryTaskItem {
  final String? itemId;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? localId;
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  @JsonKey(defaultValue: false)
  final bool isFreePrice;
  @JsonKey(defaultValue: '')
  final String driverNote;

  // Вычисляемое поле суммы для удобства на UI
  int get amountCents => lineAmountCents(quantity, price);
  double get amount => amountCents / 100;
  Map<String, dynamic> toRequestJson({bool creating = false}) => {
    if (!creating && (itemId != null || localId != null)) 'itemId': itemId,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'price': price,
    'isFreePrice': isFreePrice,
    'driverNote': driverNote,
  };

  const DeliveryTaskItem({
    this.itemId,
    this.localId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.isFreePrice = false,
    this.driverNote = '',
  });

  DeliveryTaskItem copyWith({
    int? quantity,
    double? price,
    String? driverNote,
  }) => DeliveryTaskItem(
    itemId: itemId,
    localId: localId,
    productId: productId,
    productName: productName,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
    isFreePrice: isFreePrice,
    driverNote: driverNote ?? this.driverNote,
  );

  factory DeliveryTaskItem.fromJson(Map<String, dynamic> json) =>
      _$DeliveryTaskItemFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryTaskItemToJson(this);
}
