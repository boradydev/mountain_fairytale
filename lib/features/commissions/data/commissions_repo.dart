import 'package:mountain_fairytale/core/network/api_client.dart';

import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';

abstract interface class CommissionsRepository {
  Future<CommissionReport> report(
    DateTime month, {
    required bool includeDeactivated,
  });
  Future<RepresentativeCommissionDetails> details(String id, DateTime month);
  Future<int> assign(String sourceId, String? targetId);
}

class ApiCommissionsRepository implements CommissionsRepository {
  final ApiClient client;
  ApiCommissionsRepository(this.client);

  Map<String, dynamic> _data(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);
  String _period(DateTime month) => 'year=${month.year}&month=${month.month}';

  @override
  Future<CommissionReport> report(
    DateTime month, {
    required bool includeDeactivated,
  }) async => CommissionReport.fromJson(
    _data(
      await client.get(
        '/protected/commissions?${_period(month)}&include_deactivated=$includeDeactivated',
      ),
    ),
  );
  @override
  Future<RepresentativeCommissionDetails> details(
    String id,
    DateTime month,
  ) async => RepresentativeCommissionDetails.fromJson(
    _data(
      await client.get(
        '/protected/commissions/sales-representatives/$id?${_period(month)}',
      ),
    ),
  );
  @override
  Future<int> assign(String sourceId, String? targetId) async =>
      _data(
            await client.put(
              '/protected/sales-representatives/$sourceId/clients/assignment',
              body: {'targetSalesRepresentativeId': targetId},
            ),
          )['updatedClientsCount']
          as int;
}
