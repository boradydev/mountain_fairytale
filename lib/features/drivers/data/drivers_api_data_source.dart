import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/drivers/drivers_abcs.dart';

class ApiDriverDataSource implements DriverDataSource {
  final ApiClient client;
  ApiDriverDataSource(this.client);
  static const _path = '/protected/drivers';

  Map<String, dynamic> _driver(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);

  @override
  Future<List<Map<String, dynamic>>> getAllDrivers({
    bool includeDeactivated = false,
  }) async {
    final response = await client.get(
      '$_path?include_deactivated=$includeDeactivated',
    );
    return ((response['data'] as Map)['drivers'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getDriverById(String id) async =>
      _driver(await client.get('$_path/$id'));
  @override
  Future<Map<String, dynamic>> createDriver(Map<String, dynamic> json) async =>
      _driver(await client.post('$_path/create', body: json));
  @override
  Future<Map<String, dynamic>> patchDriver(
    String id,
    Map<String, dynamic> json,
  ) async => _driver(await client.patch('$_path/$id', body: json));
  @override
  Future<void> deactivateDriver(String id) async {
    await patchDriver(id, {'isActive': false});
  }

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String name) async {
    final response = await client.get(
      '$_path/check-duplicate?name=${Uri.encodeQueryComponent(name)}',
    );
    return response['data'] == null ? null : _driver(response);
  }
}
