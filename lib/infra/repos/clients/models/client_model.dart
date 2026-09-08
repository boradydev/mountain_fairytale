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
  final int sleepingThresholdDays;

  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.lastDeliveryDate,
    this.lastDeliveryQuantity,
    this.cooldownUntil,
    required this.sleepingThresholdDays,
  });

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);

  Map<String, dynamic> toJson() => _$ClientToJson(this);
}
