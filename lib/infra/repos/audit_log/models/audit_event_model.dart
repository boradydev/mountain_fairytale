import 'package:json_annotation/json_annotation.dart';

part 'audit_event_model.g.dart';

enum AuditAction {
  created,
  updated,
  deleted,
}

@JsonSerializable()
class AuditChange {
  final String? oldValue;
  final String? newValue;

  const AuditChange({
    this.oldValue,
    this.newValue,
  });

  factory AuditChange.fromJson(Map<String, dynamic> json) =>
      _$AuditChangeFromJson(json);

  Map<String, dynamic> toJson() => _$AuditChangeToJson(this);
}

@JsonSerializable()
class AuditEvent {
  final int id;
  final DateTime createdAt;

  final int userId;
  final String userName;

  final AuditAction action;

  final String entityType;
  final int entityId;
  final String entityName;

  final Map<String, AuditChange> changes;

  const AuditEvent({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.changes,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) =>
      _$AuditEventFromJson(json);

  Map<String, dynamic> toJson() => _$AuditEventToJson(this);
}
