import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';

class AuditLogRepositoryImpl
    implements AuditLogRepository, AuditUpdatesRepository {
  final AuditLogDataSource _dataSource;
  AuditLogRepositoryImpl(this._dataSource);
  @override
  bool get supportsUpdates => _dataSource is AuditUpdatesDataSource;

  @override
  Future<AuditPage> getNewAuditEvents({
    required String after,
    String? search,
    required int limit,
  }) async {
    final source = _dataSource;
    if (source is! AuditUpdatesDataSource) {
      throw UnsupportedError('Audit source does not support updates');
    }
    return _page(
      await (source as AuditUpdatesDataSource).getNewAuditEvents(
        after: after,
        search: search,
        limit: limit,
      ),
    );
  }

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
    return _page(response);
  }

  AuditPage _page(Map<String, dynamic> response) {
    final data = response['data'] as Map;
    return AuditPage(
      events: (data['events'] as List)
          .map(
            (row) => AuditEvent.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      nextCursor: data['nextCursor'] as String?,
      latestCursor: data['latestCursor'] as String?,
    );
  }
}
