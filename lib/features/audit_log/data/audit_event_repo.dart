import 'package:mountain_fairytale/features/audit_log/data/audit_event_model.dart';
import 'package:mountain_fairytale/features/audit_log/audit_event_abcs.dart';

class AuditLogRepositoryImpl implements AuditLogRepository {
  final AuditLogDataSource _dataSource;

  AuditLogRepositoryImpl(this._dataSource);

  @override
  Future<List<AuditEvent>> getAuditEvents({
    String? search,
    required int offset,
    required int limit,
  }) async {
    final json = await _dataSource.getAuditEvents(
      search: search,
      offset: offset,
      limit: limit,
    );

    return json.map(AuditEvent.fromJson).toList();
  }
}
