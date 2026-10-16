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

class Client {
  final String id;
  final String name;
  final String phone;
  final String address;
  final int sleepingThresholdDays;
  final DateTime? lastDeliveryDate;
  final int? lastDeliveryQuantity;
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
    required this.sleepingThresholdDays,
    required this.createdAt,
    required this.isActive,
    this.lastDeliveryDate,
    this.lastDeliveryQuantity,
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
    sleepingThresholdDays: (json['sleepingThresholdDays'] as num).toInt(),
    lastDeliveryDate: json['lastDeliveryDate'] == null
        ? null
        : DateTime.parse(json['lastDeliveryDate'] as String),
    lastDeliveryQuantity: (json['lastDeliveryQuantity'] as num?)?.toInt(),
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
    'sleepingThresholdDays': sleepingThresholdDays,
    'lastDeliveryDate': lastDeliveryDate == null
        ? null
        : clientDateTime(lastDeliveryDate!),
    'lastDeliveryQuantity': lastDeliveryQuantity,
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
  final int sleepingThresholdDays;
  final DateTime? cooldownUntil;
  final String? salesRepresentativeId;
  final String? defaultPaymentMethodId;
  const CreateClientRequest({
    required this.name,
    required this.phone,
    required this.address,
    required this.sleepingThresholdDays,
    this.cooldownUntil,
    this.salesRepresentativeId,
    this.defaultPaymentMethodId,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
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
  final int? sleepingThresholdDays;
  final Object? cooldownUntil;
  final Object? salesRepresentativeId;
  final Object? defaultPaymentMethodId;
  final bool? isActive;
  const UpdateClientRequest({
    this.name,
    this.phone,
    this.address,
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
