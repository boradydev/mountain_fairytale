// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditChange _$AuditChangeFromJson(Map<String, dynamic> json) => AuditChange(
  oldValue: json['oldValue'] as String?,
  newValue: json['newValue'] as String?,
);

Map<String, dynamic> _$AuditChangeToJson(AuditChange instance) =>
    <String, dynamic>{
      'oldValue': instance.oldValue,
      'newValue': instance.newValue,
    };

AuditEvent _$AuditEventFromJson(Map<String, dynamic> json) => AuditEvent(
  id: (json['id'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  userId: (json['userId'] as num).toInt(),
  userName: json['userName'] as String,
  action: $enumDecode(_$AuditActionEnumMap, json['action']),
  entityType: json['entityType'] as String,
  entityId: (json['entityId'] as num).toInt(),
  entityName: json['entityName'] as String,
  changes: (json['changes'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, AuditChange.fromJson(e as Map<String, dynamic>)),
  ),
);

Map<String, dynamic> _$AuditEventToJson(AuditEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'userId': instance.userId,
      'userName': instance.userName,
      'action': _$AuditActionEnumMap[instance.action]!,
      'entityType': instance.entityType,
      'entityId': instance.entityId,
      'entityName': instance.entityName,
      'changes': instance.changes,
    };

const _$AuditActionEnumMap = {
  AuditAction.created: 'created',
  AuditAction.updated: 'updated',
  AuditAction.deleted: 'deleted',
};
