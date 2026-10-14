import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';

const auditFieldLabels = <String, String>{
  'name': 'Название',
  'username': 'Имя сотрудника',
  'phone': 'Телефон',
  'address': 'Адрес',
  'basePrice': 'Базовая цена',
  'price': 'Цена',
  'quantity': 'Количество',
  'isActive': 'Активность',
  'role': 'Роль',
  'commissionPercent': 'Процент комиссии',
  'model': 'Модель',
  'number': 'Номер',
  'currentMileage': 'Пробег',
  'plannedDate': 'Плановая дата',
  'startMileage': 'Начальный пробег',
  'endMileage': 'Конечный пробег',
  'driverId': 'Водитель',
  'carId': 'Автомобиль',
  'clientId': 'Клиент',
  'productId': 'Товар',
  'productName': 'Название товара',
  'position': 'Порядок',
  'items': 'Позиции',
  'points': 'Точки',
  'pointId': 'Точка',
  'documentType': 'Тип документа',
  'cooldownUntil': 'Не беспокоить до',
  'sleepingThresholdDays': 'Порог сна, дней',
  'lastDeliveryDate': 'Последняя доставка',
  'lastDeliveryQuantity': 'Количество в последней доставке',
  'salesRepresentativeId': 'Представитель',
  'defaultPaymentMethodId': 'Способ оплаты',
};

String formatAuditValue(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Да' : 'Нет';
  if (value is Map) {
    if (value['displayName'] is String) return value['displayName'] as String;
    return const JsonEncoder.withIndent('  ').convert(value);
  }
  if (value is List) return value.map(formatAuditValue).join('\n');
  if (value is String) {
    if (value == 'delivery_route_sheet') return 'Доставка';
    if (value == 'pickup_sheet') return 'Самовывоз';
    if (value == 'admin') return 'Администратор';
    if (value == 'employee') return 'Сотрудник';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}(T.*)?$').hasMatch(value)) {
      final date = DateTime.tryParse(value);
      if (date != null) {
        return DateFormat(
          value.contains('T') ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy',
        ).format(date.toLocal());
      }
    }
  }
  return value.toString();
}

class AuditEventRow extends StatelessWidget {
  final AuditEvent event;
  const AuditEventRow({super.key, required this.event});
  @override
  Widget build(BuildContext context) {
    final action = switch (event.action) {
      AuditAction.created => 'создал',
      AuditAction.updated => 'изменил',
      AuditAction.activated => 'активировал',
      AuditAction.deactivated => 'деактивировал',
      AuditAction.cancelled => 'отменил',
      AuditAction.restored => 'восстановил',
      AuditAction.deleted => 'удалил',
      AuditAction.passwordChanged => 'сменил пароль',
      AuditAction.login => 'вошёл в систему',
      AuditAction.other => 'выполнил действие (${event.eventType})',
    };
    final kind = switch (event.subject.type) {
      'product' => 'товар',
      'client' => 'клиента',
      'driver' => 'водителя',
      'car' => 'автомобиль',
      'payment_method' => 'способ оплаты',
      'sales_representative' => 'представителя',
      'employee' => 'сотрудника',
      'delivery_document' => 'документ',
      'delivery_point' => 'точку документа',
      'delivery_item' => 'позицию документа',
      _ => event.subject.type,
    };
    final name = event.subject.displayName ?? event.subject.id;
    final header = event.action == AuditAction.login
        ? action
        : '$action $kind $name';
    final fields = event.data.entries
        .where((entry) => entry.key != 'displayName')
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd.MM.yyyy HH:mm:ss').format(event.createdAt.toLocal()),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      event.actor.displayName ??
                      (event.actor.actorId ==
                              '00000000-0000-0000-0000-000000000000'
                          ? 'Система'
                          : 'Сотрудник ${event.actor.actorId}'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' $header'),
              ],
            ),
          ),
          for (final entry in event.changes.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${auditFieldLabels[entry.key] ?? entry.key}: ${formatAuditValue(entry.value.oldValue)} → ${formatAuditValue(entry.value.newValue)}',
              ),
            ),
          if (fields.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                event.action == AuditAction.deleted
                    ? 'Данные удалённой записи'
                    : 'Начальные значения',
              ),
              children: [
                for (final entry in fields)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${auditFieldLabels[entry.key] ?? entry.key}: ${formatAuditValue(entry.value)}',
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
