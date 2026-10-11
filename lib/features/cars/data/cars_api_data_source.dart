import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/cars/cars_abcs.dart';

class ApiCarDataSource implements CarDataSource {
  final ApiClient client;
  ApiCarDataSource(this.client);

  static const _path = '/protected/cars';

  Map<String, dynamic> _car(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);

  @override
  Future<List<Map<String, dynamic>>> getAllCars({
    bool includeDeactivated = false,
  }) async {
    final response = await client.get(
      '$_path?include_deactivated=$includeDeactivated',
    );
    return ((response['data'] as Map)['cars'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getCarById(String id) async =>
      _car(await client.get('$_path/$id'));

  @override
  Future<Map<String, dynamic>> createCar(Map<String, dynamic> json) async =>
      _car(await client.post('$_path/create', body: json));

  @override
  Future<Map<String, dynamic>> patchCar(
    String id,
    Map<String, dynamic> json,
  ) async => _car(await client.patch('$_path/$id', body: json));

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String number) async {
    final response = await client.get(
      '$_path/check-duplicate?number=${Uri.encodeQueryComponent(number)}',
    );
    return response['data'] == null ? null : _car(response);
  }
}
