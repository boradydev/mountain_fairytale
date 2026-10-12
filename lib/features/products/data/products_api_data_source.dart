import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';

class ApiProductDataSource implements ProductDataSource {
  final ApiClient client;

  ApiProductDataSource(this.client);

  static const _path = '/protected/products';

  Map<String, dynamic> _product(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);

  @override
  Future<List<Map<String, dynamic>>> getAllProducts({
    bool includeDeactivated = false,
  }) async {
    final response = await client.get(
      '$_path?include_deactivated=$includeDeactivated',
    );
    return ((response['data'] as Map)['products'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getProductById(String id) async =>
      _product(await client.get('$_path/$id'));

  @override
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> json) async =>
      _product(await client.post('$_path/create', body: json));

  @override
  Future<Map<String, dynamic>> patchProduct(
    String id,
    Map<String, dynamic> json,
  ) async =>
      _product(await client.patch('$_path/$id', body: json));

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String name) async {
    final response = await client.get(
      '$_path/check-duplicate?name=${Uri.encodeQueryComponent(name)}',
    );
    return response['data'] == null ? null : _product(response);
  }
}
