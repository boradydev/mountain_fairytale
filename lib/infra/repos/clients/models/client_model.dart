import 'package:json_annotation/json_annotation.dart';

part 'client_model.g.dart';

/// Модель данных клиента для системы учета доставок.
/// Содержит профиль клиента, информацию о последней активности
/// и настройки для контроля "засыпания" клиента менеджерами.
@JsonSerializable()
class Client {
  /// Уникальный идентификатор клиента в системе (ID).
  final int id;

  /// Название организации или ФИО клиента.
  final String name;

  /// Контактный номер телефона для связи.
  final String phone;

  /// Фактический адрес доставки (Населенный пункт, улица, дом).
  final String address;

  /// Дата и время последней успешной доставки.
  /// Равно [null], если доставок еще не было.
  final DateTime? lastDeliveryDate;

  /// Количество товара (например, бутылей воды), доставленное в последний раз.
  final int? lastDeliveryQuantity;

  /// Дата и время, до которых клиент "заморожен" (скрыт из списка засыпающих).
  /// Устанавливается после звонка менеджера, чтобы клиент не всплывал на дашборде
  /// определенное время (например, неделю), пока идет обработка.
  final DateTime? cooldownUntil;

  /// Индивидуальный порог "засыпания" клиента (в днях).
  /// Задается при создании клиента (например, 1 день или 7 дней).
  /// Если с момента [lastDeliveryDate] прошло больше дней, чем указано здесь,
  /// клиент автоматически считается засыпающим и попадает на дашборд.
  /// Индивидуальный порог "засыпания" клиента (в днях).
  final int sleepingThresholdDays;

  /// ID торгового представителя
  final int? salesRepresentativeId;

  /// ФИО торгового представителя
  final String? salesRepresentativeName;

  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.lastDeliveryDate,
    this.lastDeliveryQuantity,
    this.cooldownUntil,
    required this.sleepingThresholdDays,
    this.salesRepresentativeId,
    this.salesRepresentativeName,
  });

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);

  Map<String, dynamic> toJson() => _$ClientToJson(this);
}

@JsonSerializable()
class CreateClientRequest {
  final String name;
  final String phone;
  final String address;
  final int sleepingThresholdDays;
  final int? salesRepresentativeId;
  final String? salesRepresentativeName;

  const CreateClientRequest({
    required this.name,
    required this.phone,
    required this.address,
    required this.sleepingThresholdDays,
    this.salesRepresentativeId,
    this.salesRepresentativeName,
  });

  Map<String, dynamic> toJson() => _$CreateClientRequestToJson(this);
}

@JsonSerializable(
    includeIfNull: true) // Поменяли на true, чтобы можно было занулить / перетереть при редактировании
class UpdateClientRequest {
  final String? name;
  final String? phone;
  final String? address;
  final int? sleepingThresholdDays;
  final int? salesRepresentativeId;
  final String? salesRepresentativeName;

  const UpdateClientRequest({
    this.name,
    this.phone,
    this.address,
    this.sleepingThresholdDays,
    this.salesRepresentativeId,
    this.salesRepresentativeName,
  });

  Map<String, dynamic> toJson() => _$UpdateClientRequestToJson(this);
}

