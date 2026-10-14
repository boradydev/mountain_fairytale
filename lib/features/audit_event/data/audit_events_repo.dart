import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';

class AuditLogRepositoryImpl
    implements
        AuditLogRepository,
        AuditUpdatesRepository,
        AuditFilteredRepository {
  final AuditLogDataSource _dataSource;
  AuditLogRepositoryImpl(this._dataSource);
  @override
  bool get supportsUpdates => _dataSource is AuditUpdatesDataSource;

  @override
  Future<AuditPage> getNewAuditEvents({
    required String after,
    String? search,
    required int limit,
    AuditFilters filters = const AuditFilters(),
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
        filters: filters,
      ),
    );
  }

  @override
  Future<AuditPage> getFilteredAuditEvents({
    required AuditFilters filters,
    String? search,
    String? cursor,
    required int limit,
  }) async {
    final source = _dataSource;
    if (source is! AuditFilteredDataSource) {
      throw UnsupportedError('Audit source does not support filters');
    }
    return _page(
      await (source as AuditFilteredDataSource).getFilteredAuditEvents(
        filters: filters,
        search: search,
        cursor: cursor,
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
