import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';

class ApiAuditLogDataSource implements AuditLogDataSource {
  final ApiClient client;
  ApiAuditLogDataSource(this.client);
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
