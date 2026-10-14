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

abstract interface class AuditUpdatesDataSource {
  Future<Map<String, dynamic>> getNewAuditEvents({
    required String after,
    String? search,
    required int limit,
  });
}

abstract interface class AuditUpdatesRepository {
  bool get supportsUpdates;
  Future<AuditPage> getNewAuditEvents({
    required String after,
    String? search,
    required int limit,
  });
}
