import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';

class ApiAuditLogDataSource
    implements
        AuditLogDataSource,
        AuditUpdatesDataSource,
        AuditFilteredDataSource {
  final ApiClient client;
  ApiAuditLogDataSource(this.client);
  @override
  Future<Map<String, dynamic>> getNewAuditEvents({
    required String after,
    String? search,
    required int limit,
    AuditFilters filters = const AuditFilters(),
  }) => client.get(
    Uri(
      path: '/protected/events',
      queryParameters: {
        'limit': '$limit',
        'after': after,
        ...filters.queryParameters,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    ).toString(),
  );
  @override
  Future<Map<String, dynamic>> getFilteredAuditEvents({
    required AuditFilters filters,
    String? search,
    String? cursor,
    required int limit,
  }) => client.get(
    Uri(
      path: '/protected/events',
      queryParameters: {
        'limit': '$limit',
        'cursor': ?cursor,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        ...filters.queryParameters,
      },
    ).toString(),
  );
  @override
  Future<Map<String, dynamic>> getAuditEvents({
    String? search,
    String? cursor,
    required int limit,
  }) {
    final uri = Uri(
      path: '/protected/events',
      queryParameters: {
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'cursor': ?cursor,
      },
    );
    return client.get(uri.toString());
  }
}
