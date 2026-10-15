import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';

class DashboardUpdates {
  final String serverId;
  final int version;
  final bool clientsChanged;
  final bool deliveryDaysChanged;
  final bool reloadRequired;
  const DashboardUpdates({
    required this.serverId,
    required this.version,
    required this.clientsChanged,
    required this.deliveryDaysChanged,
    required this.reloadRequired,
  });
  factory DashboardUpdates.fromJson(Map<String, dynamic> json) =>
      DashboardUpdates(
        serverId: json['serverId'] as String,
        version: json['version'] as int,
        clientsChanged: json['clientsChanged'] as bool,
        deliveryDaysChanged: json['deliveryDaysChanged'] as bool,
        reloadRequired: json['reloadRequired'] as bool,
      );
}

class DashboardUpdatesRepository {
  final ApiClient _client;
  DashboardUpdatesRepository(this._client);

  Future<DashboardUpdates> wait({
    DashboardUpdates? after,
    required HttpRequestCancellation cancellation,
  }) async {
    final uri = Uri(
      path: '/protected/dashboard-updates',
      queryParameters: {
        'timeout': after == null ? '0' : '25',
        if (after != null) 'server_id': after.serverId,
        if (after != null) 'version': '${after.version}',
      },
    );
    final response = await _client.longPoll(uri.toString(), cancellation);
    return DashboardUpdates.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }
}
