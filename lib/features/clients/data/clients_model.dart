import 'package:mountain_fairytale/features/clients/data/location_repository.dart';

const _omitted = Object();

/// Keep server-local timestamps without timezone conversion.
String clientDateTime(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
).toIso8601String();

class ClientOrderItem {
  final String productId;
  final String productName;
  final int quantity;

  const ClientOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory ClientOrderItem.fromJson(Map<String, dynamic> json) =>
      ClientOrderItem(
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        quantity: (json['quantity'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
  };
  String get description => '$productName × $quantity';
}

class ClientLastOrder {
  final DateTime date;
  final List<String> fulfillmentTypes;
  final List<ClientOrderItem> items;

  const ClientLastOrder({
    required this.date,
    required this.fulfillmentTypes,
    required this.items,
  });

  factory ClientLastOrder.fromJson(Map<String, dynamic> json) =>
      ClientLastOrder(
        date: DateTime.parse(json['date'] as String),
        fulfillmentTypes: (json['fulfillmentTypes'] as List).cast<String>(),
        items: (json['items'] as List)
            .map(
              (item) => ClientOrderItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );

  String get fulfillmentLabel => fulfillmentTypes.length > 1
      ? 'Доставка и самовывоз'
      : fulfillmentTypes.contains('pickup')
      ? 'Самовывоз'
      : 'Доставка';

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'fulfillmentTypes': fulfillmentTypes,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class Client {
  final String id;
  final String name;
  final String phone;
  final String address;
  final DeliveryAddress? deliveryAddress;
  final String deliveryDetails;
  final int sleepingThresholdDays;
  final DateTime? lastDeliveryDate;
  final int? lastDeliveryQuantity;
  final ClientLastOrder? lastOrder;
  final DateTime? cooldownUntil;
  final String? salesRepresentativeId;
  final String? salesRepresentativeName;
  final String? defaultPaymentMethodId;
  final String? defaultPaymentMethodName;
  final DateTime createdAt;
  final bool isActive;
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.deliveryAddress,
    this.deliveryDetails = '',
    required this.sleepingThresholdDays,
    required this.createdAt,
    required this.isActive,
    this.lastDeliveryDate,
    this.lastDeliveryQuantity,
    this.lastOrder,
    this.cooldownUntil,
    this.salesRepresentativeId,
    this.salesRepresentativeName,
    this.defaultPaymentMethodId,
    this.defaultPaymentMethodName,
  });
  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['clientId'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    address: json['address'] as String,
    deliveryDetails: json['deliveryDetails'] as String? ?? '',
    deliveryAddress: json['deliveryAddress'] == null
        ? null
        : DeliveryAddress.fromJson(
            Map<String, dynamic>.from(json['deliveryAddress'] as Map),
          ),
    sleepingThresholdDays: (json['sleepingThresholdDays'] as num).toInt(),
    lastDeliveryDate: json['lastDeliveryDate'] == null
        ? null
        : DateTime.parse(json['lastDeliveryDate'] as String),
    lastDeliveryQuantity: (json['lastDeliveryQuantity'] as num?)?.toInt(),
    lastOrder: json['lastOrder'] == null
        ? null
        : ClientLastOrder.fromJson(
            Map<String, dynamic>.from(json['lastOrder'] as Map),
          ),
    cooldownUntil: json['cooldownUntil'] == null
        ? null
        : DateTime.parse(json['cooldownUntil'] as String),
    salesRepresentativeId: json['salesRepresentativeId'] as String?,
    salesRepresentativeName: json['salesRepresentativeName'] as String?,
    defaultPaymentMethodId: json['defaultPaymentMethodId'] as String?,
    defaultPaymentMethodName: json['defaultPaymentMethodName'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isActive: json['isActive'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'clientId': id,
    'name': name,
    'phone': phone,
    'address': address,
    'deliveryDetails': deliveryDetails,
    if (deliveryAddress != null) 'deliveryAddress': deliveryAddress!.toJson(),
    'sleepingThresholdDays': sleepingThresholdDays,
    'lastDeliveryDate': lastDeliveryDate == null
        ? null
        : clientDateTime(lastDeliveryDate!),
    'lastDeliveryQuantity': lastDeliveryQuantity,
    'lastOrder': lastOrder?.toJson(),
    'cooldownUntil': cooldownUntil == null
        ? null
        : clientDateTime(cooldownUntil!),
    'salesRepresentativeId': salesRepresentativeId,
    'salesRepresentativeName': salesRepresentativeName,
    'defaultPaymentMethodId': defaultPaymentMethodId,
    'defaultPaymentMethodName': defaultPaymentMethodName,
    'createdAt': clientDateTime(createdAt),
    'isActive': isActive,
  };

  DateTime? get lastOrderDate => lastOrder?.date ?? lastDeliveryDate;

  int? daysSinceLastOrder(DateTime now) {
    final date = lastOrderDate;
    if (date == null) return null;
    // UTC date-only values avoid daylight-saving and time-of-day differences.
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  }
}

class ClientDirectoryEntry {
  final String id;
  final String name;
  final bool isActive;
  const ClientDirectoryEntry(this.id, this.name, {this.isActive = true});
}

class CreateClientRequest {
  final String name;
  final String phone;
  final String address;
  final DeliveryAddress? deliveryAddress;
  final String deliveryDetails;
  final int sleepingThresholdDays;
  final DateTime? cooldownUntil;
  final String? salesRepresentativeId;
  final String? defaultPaymentMethodId;
  const CreateClientRequest({
    required this.name,
    required this.phone,
    required this.address,
    this.deliveryAddress,
    this.deliveryDetails = '',
    required this.sleepingThresholdDays,
    this.cooldownUntil,
    this.salesRepresentativeId,
    this.defaultPaymentMethodId,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'deliveryDetails': deliveryDetails,
    if (deliveryAddress != null) 'deliveryAddress': deliveryAddress!.toJson(),
    'sleepingThresholdDays': sleepingThresholdDays,
    'cooldownUntil': cooldownUntil == null
        ? null
        : clientDateTime(cooldownUntil!),
    'salesRepresentativeId': salesRepresentativeId,
    'defaultPaymentMethodId': defaultPaymentMethodId,
  };
}

/// A sentinel distinguishes omitted nullable fields from explicit null.
class UpdateClientRequest {
  final String? name;
  final String? phone;
  final String? address;
  final Object? deliveryAddress;
  final String? deliveryDetails;
  final int? sleepingThresholdDays;
  final Object? cooldownUntil;
  final Object? salesRepresentativeId;
  final Object? defaultPaymentMethodId;
  final bool? isActive;
  const UpdateClientRequest({
    this.name,
    this.phone,
    this.address,
    this.deliveryAddress = _omitted,
    this.deliveryDetails,
    this.sleepingThresholdDays,
    this.cooldownUntil = _omitted,
    this.salesRepresentativeId = _omitted,
    this.defaultPaymentMethodId = _omitted,
    this.isActive,
  });
  factory UpdateClientRequest.fromChanges(Map<String, Object?> changes) =>
      UpdateClientRequest(
        name: changes['name'] as String?,
        phone: changes['phone'] as String?,
        address: changes['address'] as String?,
        deliveryAddress: changes.containsKey('deliveryAddress')
            ? changes['deliveryAddress']
            : _omitted,
        deliveryDetails: changes['deliveryDetails'] as String?,
        sleepingThresholdDays: changes['sleepingThresholdDays'] as int?,
        cooldownUntil: changes.containsKey('cooldownUntil')
            ? changes['cooldownUntil']
            : _omitted,
        salesRepresentativeId: changes.containsKey('salesRepresentativeId')
            ? changes['salesRepresentativeId']
            : _omitted,
        defaultPaymentMethodId: changes.containsKey('defaultPaymentMethodId')
            ? changes['defaultPaymentMethodId']
            : _omitted,
      );
  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (phone != null) 'phone': phone,
    if (address != null) 'address': address,
    if (deliveryDetails != null) 'deliveryDetails': deliveryDetails,
    if (!identical(deliveryAddress, _omitted))
      'deliveryAddress': (deliveryAddress as DeliveryAddress?)?.toJson(),
    if (sleepingThresholdDays != null)
      'sleepingThresholdDays': sleepingThresholdDays,
    if (!identical(cooldownUntil, _omitted))
      'cooldownUntil': cooldownUntil == null
          ? null
          : clientDateTime(cooldownUntil as DateTime),
    if (!identical(salesRepresentativeId, _omitted))
      'salesRepresentativeId': salesRepresentativeId as String?,
    if (!identical(defaultPaymentMethodId, _omitted))
      'defaultPaymentMethodId': defaultPaymentMethodId as String?,
    if (isActive != null) 'isActive': isActive,
  };
}
