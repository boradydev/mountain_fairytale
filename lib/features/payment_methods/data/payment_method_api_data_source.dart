import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';

class ApiPaymentMethodDataSource implements PaymentMethodDataSource {
  final ApiClient client;

  ApiPaymentMethodDataSource(this.client);

  static const _path = '/protected/payment-methods';

  Map<String, dynamic> _paymentMethod(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map);

  @override
  Future<List<Map<String, dynamic>>> getAllPaymentMethods({
    bool includeDeactivated = false,
  }) async {
    final response = await client.get(
      '$_path?include_deactivated=$includeDeactivated',
    );
    return ((response['data'] as Map)['paymentMethods'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getPaymentMethodById(String id) async =>
      _paymentMethod(await client.get('$_path/$id'));

  @override
  Future<Map<String, dynamic>> createPaymentMethod(
    Map<String, dynamic> json,
  ) async => _paymentMethod(await client.post('$_path/create', body: json));

  @override
  Future<Map<String, dynamic>> patchPaymentMethod(
    String id,
    Map<String, dynamic> json,
  ) async => _paymentMethod(await client.patch('$_path/$id', body: json));

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String name) async {
    final response = await client.get(
      '$_path/check-duplicate?name=${Uri.encodeQueryComponent(name)}',
    );
    return response['data'] == null ? null : _paymentMethod(response);
  }
}
