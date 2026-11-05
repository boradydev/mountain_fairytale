import 'package:intl/intl.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';
import 'package:mountain_fairytale/features/delivery_history/delivery_history_abcs.dart';

class ApiDeliveryHistoryRepository implements DeliveryHistoryRepository {
  final ApiClient _client;
  ApiDeliveryHistoryRepository(this._client);

  @override
  Future<DeliveryHistoryPage> getHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String search,
    required bool includeCancelled,
    required int offset,
    required int limit,
    String documentType = 'all',
  }) async {
    final format = DateFormat('yyyy-MM-dd');
    final response = await _client.get(
      Uri(
        path: '/protected/delivery-history',
        queryParameters: {
          'date_from': format.format(dateFrom),
          'date_to': format.format(dateTo),
          if (search.isNotEmpty) 'search': search,
          'document_type': documentType,
          'include_cancelled': '$includeCancelled',
          'offset': '$offset',
          'limit': '$limit',
        },
      ).toString(),
    );
    return DeliveryHistoryPage.fromJson(response);
  }

  @override
  Future<ClientDeliveryHistoryPage> getClientHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String search,
    required int offset,
    required int limit,
  }) async {
    final format = DateFormat('yyyy-MM-dd');
    return ClientDeliveryHistoryPage.fromJson(
      await _client.get(
        Uri(
          path: '/protected/client-delivery-history',
          queryParameters: {
            'date_from': format.format(dateFrom),
            'date_to': format.format(dateTo),
            'search': search,
            'offset': '$offset',
            'limit': '$limit',
          },
        ).toString(),
      ),
    );
  }
}
