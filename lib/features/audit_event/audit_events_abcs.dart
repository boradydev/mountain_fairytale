import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';

abstract interface class AuditLogDataSource {
  Future<Map<String, dynamic>> getAuditEvents({
    String? search,
    String? cursor,
    required int limit,
  });
}

abstract interface class AuditLogRepository {
  Future<AuditPage> getAuditEvents({
    String? search,
    String? cursor,
    required int limit,
  });
}
