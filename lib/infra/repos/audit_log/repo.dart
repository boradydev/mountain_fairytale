import 'package:mountain_fairytale/infra/repos/audit_log/models/audit_event_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/audit_log_contracts.dart';

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
