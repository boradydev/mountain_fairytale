import 'package:mountain_fairytale/core/network/api_client.dart';

class ApiSalesRepresentative {
  final String id;
  final String name;
  final String phone;
  final double commissionPercent;
  final bool isActive;
  const ApiSalesRepresentative({
    required this.id,
    required this.name,
    required this.phone,
    required this.commissionPercent,
    required this.isActive,
  });
  factory ApiSalesRepresentative.fromJson(Map<String, dynamic> json) =>
      ApiSalesRepresentative(
        id: json['salesRepresentativeId'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        commissionPercent: (json['commissionPercent'] as num).toDouble(),
        isActive: json['isActive'] as bool,
      );
}

/// API directory used by the client form; demo commission reports stay isolated.
class SalesRepresentativeApiRepository {
  final ApiClient client;
  SalesRepresentativeApiRepository(this.client);
  static const _path = '/protected/sales-representatives';
  Future<List<ApiSalesRepresentative>> getAll({
    bool includeDeactivated = false,
  }) async {
    final response = await client.get(
      Uri(
        path: _path,
        queryParameters: {
          'include_deactivated': '$includeDeactivated',
        },
      ).toString(),
    );
    final data = response['data'] as Map;
    return (data['salesRepresentatives'] as List)
        .map(
          (row) => ApiSalesRepresentative.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  ApiSalesRepresentative _record(Map<String, dynamic> response) =>
      ApiSalesRepresentative.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
  Future<ApiSalesRepresentative> get(String id) async =>
      _record(await client.get('$_path/$id'));
  Future<ApiSalesRepresentative> create({
    required String name,
    required String phone,
    required double commissionPercent,
  }) async => _record(
    await client.post(
      '$_path/create',
      body: {
        'name': name,
        'phone': phone,
        'commissionPercent': commissionPercent,
      },
    ),
  );
  Future<ApiSalesRepresentative> update(
    String id,
    Map<String, dynamic> changes,
  ) async => _record(await client.patch('$_path/$id', body: changes));
  Future<ApiSalesRepresentative?> checkDuplicate(
    String name,
    String phone,
  ) async {
    final response = await client.get(
      Uri(
        path: '$_path/check-duplicate',
        queryParameters: {'name': name, 'phone': phone},
      ).toString(),
    );
    return response['data'] == null ? null : _record(response);
  }
}
