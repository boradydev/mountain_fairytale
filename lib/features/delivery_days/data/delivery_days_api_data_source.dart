import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';

class ApiDeliveryDaysDataSource implements DeliveryDataSource {
  final ApiClient client;
  ApiDeliveryDaysDataSource(this.client);
  @override
  Future<Map<String, dynamic>> getDeliveryDays({
    required int offset,
    required int limit,
  }) => client.get('/protected/delivery-days?offset=$offset&limit=$limit');
  @override
  Future<List<Map<String, dynamic>>> getDayDocuments(
    DateTime date, {
    bool includeCancelled = false,
  }) async {
    final plannedDate = date.toIso8601String().substring(0, 10);
    final response = await client.get(
      '/protected/delivery-days/$plannedDate/documents?include_cancelled=$includeCancelled',
    );
    return ((response['data'] as Map)['documents'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
