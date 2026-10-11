import 'package:mountain_fairytale/features/audit_event/data/audit_event_model.dart';

abstract interface class AuditLogDataSource {
  Future<List<Map<String, dynamic>>> getAuditEvents({
    String? search,
    required int offset,
    required int limit,
  });
}

abstract interface class AuditLogRepository {
  Future<List<AuditEvent>> getAuditEvents({
    String? search,
    required int offset,
    required int limit,
  });
}
