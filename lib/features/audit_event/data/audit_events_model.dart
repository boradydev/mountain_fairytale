enum AuditAction {
  created,
  updated,
  activated,
  deactivated,
  cancelled,
  restored,
  deleted,
  passwordChanged,
  login,
  other;

  static AuditAction fromCode(String code) => switch (code) {
    'password_changed' => passwordChanged,
    _ => values.firstWhere((value) => value.name == code, orElse: () => other),
  };
}

class AuditChange {
  final Object? oldValue;
  final Object? newValue;
  const AuditChange({required this.oldValue, required this.newValue});
  factory AuditChange.fromJson(Map<String, dynamic> json) =>
      AuditChange(oldValue: json['oldValue'], newValue: json['newValue']);
}

class AuditActor {
  final String actorId;
  final String? displayName;
  const AuditActor({required this.actorId, this.displayName});
  factory AuditActor.fromJson(Map<String, dynamic> json) => AuditActor(
    actorId: json['actorId'] as String,
    displayName: json['displayName'] as String?,
  );
}

class AuditSubject {
  final String type;
  final String id;
  final String? displayName;
  final String? documentType;
  const AuditSubject({
    required this.type,
    required this.id,
    this.displayName,
    this.documentType,
  });
  factory AuditSubject.fromJson(Map<String, dynamic> json) => AuditSubject(
    type: json['type'] as String,
    id: json['id'] as String,
    displayName: json['displayName'] as String?,
    documentType: json['documentType'] as String?,
  );
}

class AuditEvent {
  final String eventId;
  final String operationId;
  final String eventType;
  final DateTime createdAt;
  final AuditActor actor;
  final AuditAction action;
  final AuditSubject subject;
  final Map<String, Object?> data;
  final Map<String, AuditChange> changes;
  const AuditEvent({
    required this.eventId,
    required this.operationId,
    required this.eventType,
    required this.createdAt,
    required this.actor,
    required this.action,
    required this.subject,
    required this.data,
    required this.changes,
  });
  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
    eventId: json['eventId'] as String,
    operationId: json['operationId'] as String,
    eventType: json['eventType'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    actor: AuditActor.fromJson(Map<String, dynamic>.from(json['actor'] as Map)),
    action: AuditAction.fromCode(json['action'] as String),
    subject: AuditSubject.fromJson(
      Map<String, dynamic>.from(json['subject'] as Map),
    ),
    data: Map<String, Object?>.from(json['data'] as Map? ?? const {}),
    changes: (json['changes'] as Map? ?? const {}).map(
      (key, value) => MapEntry(
        key as String,
        AuditChange.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    ),
  );
}

class AuditPage {
  final List<AuditEvent> events;
  final String? nextCursor;
  const AuditPage({required this.events, this.nextCursor});
}

class AuditOperation {
  final String operationId;
  final List<AuditEvent> events;
  const AuditOperation(this.operationId, this.events);
  AuditEvent get primaryEvent => events.firstWhere(
    (event) => event.subject.type == 'delivery_document',
    orElse: () => events.first,
  );
}
