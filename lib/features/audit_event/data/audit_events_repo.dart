import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';

class AuditLogRepositoryImpl implements AuditLogRepository {
  final AuditLogDataSource _dataSource;
  AuditLogRepositoryImpl(this._dataSource);
  @override
  Future<AuditPage> getAuditEvents({
    String? search,
    String? cursor,
    required int limit,
  }) async {
    final response = await _dataSource.getAuditEvents(
      search: search,
      cursor: cursor,
      limit: limit,
    );
    final data = response['data'] as Map;
    return AuditPage(
      events: (data['events'] as List)
          .map(
            (row) => AuditEvent.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }
}
