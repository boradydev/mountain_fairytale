import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';

part 'audit_document_details.dart';

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
    if (value.containsKey('displayName') && value['id'] is String) {
      return value['id'] as String;
    }
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

String auditActorName(AuditEvent event) =>
    event.actor.displayName ??
    (event.actor.actorId == '00000000-0000-0000-0000-000000000000'
        ? 'Система'
        : 'Сотрудник ${event.actor.actorId}');

String auditSubjectName(AuditEvent event) {
  final name = event.subject.displayName ?? event.subject.id;
  if (event.subject.type != 'delivery_document') {
    final label = switch (event.subject.type) {
      'product' => 'Товар',
      'client' => 'Клиент',
      'driver' => 'Водитель',
      'car' => 'Автомобиль',
      'payment_method' => 'Способ оплаты',
      'sales_representative' => 'Представитель',
      'employee' => 'Сотрудник',
      'delivery_point' => 'Точка',
      'delivery_item' => 'Товар в точке',
      _ => event.subject.type,
    };
    return '$label: $name';
  }
  final type = event.subject.documentType ?? event.data['documentType'];
  final label = switch (type) {
    'delivery_route_sheet' => 'Маршрутный лист',
    'pickup_sheet' => 'Лист самовывоза',
    _ => 'Документ',
  };
  return '$label: ${formatAuditValue(name)}';
}

String auditSummary(AuditEvent event) {
  final actor = auditActorName(event);
  return event.action == AuditAction.login
      ? '$actor — вошёл в систему'
      : '$actor → ${auditSubjectName(event)}';
}

String auditActionLabel(AuditAction action) => switch (action) {
  AuditAction.created => 'Создание',
  AuditAction.updated => 'Изменение',
  AuditAction.activated => 'Активация',
  AuditAction.deactivated => 'Деактивация',
  AuditAction.cancelled => 'Отмена документа',
  AuditAction.restored => 'Восстановление документа',
  AuditAction.deleted => 'Удаление',
  AuditAction.passwordChanged => 'Смена пароля',
  AuditAction.login => 'Вход в систему',
  AuditAction.other => 'Другое действие',
};

IconData auditActionIcon(AuditAction action) => switch (action) {
  AuditAction.created => Icons.add_circle_outline,
  AuditAction.updated => Icons.edit_outlined,
  AuditAction.activated => Icons.toggle_on_outlined,
  AuditAction.deactivated => Icons.pause_circle_outline,
  AuditAction.cancelled => Icons.block_outlined,
  AuditAction.restored => Icons.restore,
  AuditAction.deleted => Icons.delete_outline,
  AuditAction.passwordChanged => Icons.key_outlined,
  AuditAction.login => Icons.login,
  AuditAction.other => Icons.more_horiz,
};

Color auditActionColor(AuditAction action, ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  return switch (action) {
    AuditAction.created || AuditAction.activated =>
      dark ? Colors.green.shade400 : Colors.green.shade700,
    AuditAction.updated => dark ? Colors.blue.shade300 : Colors.blue.shade700,
    AuditAction.deactivated || AuditAction.deleted => theme.colorScheme.error,
    AuditAction.cancelled =>
      dark ? Colors.orange.shade300 : Colors.orange.shade800,
    AuditAction.restored => dark ? Colors.teal.shade300 : Colors.teal.shade700,
    AuditAction.passwordChanged =>
      dark ? Colors.purple.shade300 : Colors.purple.shade700,
    AuditAction.login ||
    AuditAction.other => theme.colorScheme.onSurfaceVariant,
  };
}

class AuditOperationRow extends StatelessWidget {
  final AuditOperation operation;
  const AuditOperationRow({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    final primary = operation.primaryEvent;
    return AuditEventRow(
      event: primary,
      relatedEvents: operation.events
          .where((event) => event.eventId != primary.eventId)
          .toList(),
    );
  }
}

class AuditEventRow extends StatefulWidget {
  final AuditEvent event;
  final List<AuditEvent> relatedEvents;
  const AuditEventRow({
    super.key,
    required this.event,
    this.relatedEvents = const [],
  });

  @override
  State<AuditEventRow> createState() => _AuditEventRowState();
}

class _AuditEventRowState extends State<AuditEventRow> {
  bool _expanded = false;
  void _toggle() => setState(() => _expanded = !_expanded);

  bool get _hasDetails =>
      widget.relatedEvents.isNotEmpty ||
      widget.event.changes.isNotEmpty ||
      widget.event.data.keys.any((key) => key != 'displayName');

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final theme = Theme.of(context);
    final summary = auditSummary(event);
    final action = auditActionLabel(event.action);
    final document = event.subject.type == 'delivery_document';
    final hasPointSnapshots =
        event.data['points'] is List || event.changes['points'] != null;
    final relatedEvents = widget.relatedEvents
        .where(
          (related) =>
              !(document &&
                  hasPointSnapshots &&
                  {
                    'delivery_point',
                    'delivery_item',
                  }.contains(related.subject.type)),
        )
        .toList();
    final date = DateFormat('dd.MM.yyyy HH:mm')
        .format(event.createdAt.toLocal());
    final fullDate = DateFormat('dd.MM.yyyy HH:mm:ss')
        .format(event.createdAt.toLocal());
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: _hasDetails,
            expanded: _hasDetails ? _expanded : null,
            label: '$action. $fullDate. $summary',
            excludeSemantics: true,
            onTap: _hasDetails ? _toggle : null,
            child: InkWell(
              key: ValueKey('audit-header-${event.operationId}'),
              onTap: _hasDetails ? _toggle : null,
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(context)
                          .scale(1);
                      final compact = constraints.maxWidth < 650 * textScale;
                      final dateWidth = constraints.maxWidth >= 600
                          ? 140.0
                          : 110.0;
                      final actionText = Tooltip(
                        message: action,
                        child: Text(
                          action,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Tooltip(
                                message: action,
                                child: Icon(
                                  auditActionIcon(event.action),
                                  color: auditActionColor(event.action, theme),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: dateWidth,
                                child: Tooltip(
                                  message: fullDate,
                                  child: Text(
                                    date,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (compact)
                                Expanded(child: actionText)
                              else
                                SizedBox(
                                  width: 200 * textScale,
                                  child: actionText,
                                ),
                              if (!compact) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Tooltip(
                                    message: summary,
                                    child: Text(
                                      summary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 20,
                                child: _hasDetails
                                    ? Tooltip(
                                        message: _expanded
                                            ? 'Скрыть подробности'
                                            : 'Показать подробности',
                                        child: AnimatedRotation(
                                          turns: _expanded ? 0.5 : 0,
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          child: Icon(
                                            Icons.expand_more,
                                            size: 20,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          if (compact)
                            Padding(
                              padding: const EdgeInsets.only(left: 30, top: 4),
                              child: Tooltip(
                                message: summary,
                                child: Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded && _hasDetails
                ? Container(
                    key: ValueKey('details-${event.operationId}'),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(42, 8, 16, 16),
                    color: theme.colorScheme.surfaceContainerLowest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AuditDetails(event: event),
                        if (relatedEvents.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 6),
                            child: Text(
                              'Связанные изменения',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          for (final related in relatedEvents)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _AuditDisclosure(
                                key: ValueKey(
                                  'audit-related-${related.eventId}',
                                ),
                                label: auditSummary(related),
                                action: related.action,
                                child: _AuditDetails(event: related),
                              ),
                            ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AuditDetails extends StatelessWidget {
  final AuditEvent event;
  const _AuditDetails({required this.event});

  @override
  Widget build(BuildContext context) {
    final document = event.subject.type == 'delivery_document';
    final pickup =
        (event.subject.documentType ?? event.data['documentType']) ==
        'pickup_sheet';
    bool visible(String key) =>
        key != 'displayName' &&
        (!document ||
            (key != 'points' &&
                key != 'documentType' &&
                !(pickup &&
                    {
                      'driverId',
                      'carId',
                      'startMileage',
                      'endMileage',
                    }.contains(key))));
    final keys = {
      ...event.data.keys,
      ...event.changes.keys,
    }.where(visible).toList();
    const order = [
      'plannedDate',
      'driverId',
      'carId',
      'startMileage',
      'endMileage',
    ];
    if (document) {
      keys.sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        return (ai < 0 ? order.length : ai).compareTo(
          bi < 0 ? order.length : bi,
        );
      });
    }
    final fields = event.data.entries.where(
      (entry) => entry.key != 'displayName',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (document) ...[
          for (final key in keys)
            _AuditFieldRow(
              label: auditFieldLabels[key] ?? key,
              value: event.data[key],
              change: event.changes[key],
            ),
          _AuditDocumentPoints(event: event),
        ] else ...[
          for (final entry in fields)
            _AuditFieldRow(
              label: auditFieldLabels[entry.key] ?? entry.key,
              value: entry.value,
            ),
          for (final entry in event.changes.entries)
            _AuditFieldRow(
              label: auditFieldLabels[entry.key] ?? entry.key,
              change: entry.value,
            ),
        ],
      ],
    );
  }
}

class _AuditFieldRow extends StatelessWidget {
  final String label;
  final Object? value;
  final AuditChange? change;
  const _AuditFieldRow({required this.label, this.value, this.change});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget text(Object? value) => SelectableText(
      formatAuditValue(value),
      style: theme.textTheme.bodySmall,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
          final values = change == null
              ? text(value)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: text(change!.oldValue)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('→', style: theme.textTheme.bodySmall),
                    ),
                    Expanded(child: text(change!.newValue)),
                  ],
                );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                values,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 156, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: values),
            ],
          );
        },
      ),
    );
  }
}
