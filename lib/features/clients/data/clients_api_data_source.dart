import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';

class ApiClientDataSource implements ClientDataSource {
  final ApiClient client;
  ApiClientDataSource(this.client);
  static const _path = '/protected/clients';
  Map<String, dynamic> _data(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);
  @override
  Future<List<Map<String, dynamic>>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  }) async {
    final rows = <Map<String, dynamic>>[];
    // Fetch all pages so the sleeping dashboard sees the complete active list.
    while (true) {
      final uri = Uri(
        path: _path,
        queryParameters: {
          'include_deactivated': '$includeDeactivated',
          'offset': '${rows.length}',
          'limit': '100',
          'search': ?search,
        },
      );
      final response = await client.get(uri.toString());
      final page = (_data(response)['clients'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      rows.addAll(page);
      if (page.isEmpty || rows.length >= (response['total'] as num).toInt()) {
        return rows;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getClientById(String id) async =>
      _data(await client.get('$_path/$id'));
  @override
  Future<Map<String, dynamic>> createClient(Map<String, dynamic> json) async =>
      _data(await client.post('$_path/create', body: json));
  @override
  Future<Map<String, dynamic>> patchClient(
    String id,
    Map<String, dynamic> json,
  ) async => _data(await client.patch('$_path/$id', body: json));
  @override
  Future<Map<String, dynamic>?> checkDuplicate(
    String name,
    String phone,
    String address,
  ) async {
    final uri = Uri(
      path: '$_path/check-duplicate',
      queryParameters: {'name': name, 'phone': phone, 'address': address},
    );
    final response = await client.get(uri.toString());
    return response['data'] == null ? null : _data(response);
  }

  Future<List<ClientDirectoryEntry>> _directory(
    String path,
    String key,
    String idKey,
  ) async {
    final response = await client.get(
      '/protected/$path?include_deactivated=false',
    );
    return (_data(response)[key] as List)
        .map(
          (row) =>
              ClientDirectoryEntry(row[idKey] as String, row['name'] as String),
        )
        .toList();
  }

  @override
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives() => _directory(
    'sales-representatives',
    'salesRepresentatives',
    'salesRepresentativeId',
  );
  @override
  Future<List<ClientDirectoryEntry>> getPaymentMethods() =>
      _directory('payment-methods', 'paymentMethods', 'paymentMethodId');
}
