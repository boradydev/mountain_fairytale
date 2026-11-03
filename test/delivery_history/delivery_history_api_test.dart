import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_api_repo.dart';

class _ApiClient implements ApiClient {
  Uri? request;
  @override
  Future<Map<String, dynamic>> get(String path) async {
    request = Uri.parse(path);
    return {
      'offset': 25,
      'limit': 25,
      'total': 40,
      'data': {
        'documents': [
          {
            'deliveryDocumentId': 'saved-document',
            'documentType': 'pickupSheet',
            'plannedDate': '2026-11-03',
            'isActive': false,
            'driverName': null,
            'carModelAndNumber': null,
            'clientsCount': 0,
            'purchasesCount': 3,
            'totalAmount': '1234.56',
            'matchedClients': [],
          },
        ],
      },
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('required planned dates and literal search survive URI encoding; reads whole-document totals', () async {
    final client = _ApiClient();
    final repo = ApiDeliveryHistoryRepository(client);
    final page = await repo.getHistory(
      dateFrom: DateTime(2026, 10, 5),
      dateTo: DateTime(2026, 11, 3),
      search: r'Магазин %_\ +7',
      includeCancelled: true,
      offset: 25,
      limit: 25,
    );
    expect(client.request!.path, '/protected/delivery-history');
    expect(client.request!.queryParameters, {
      'date_from': '2026-10-05',
      'date_to': '2026-11-03',
      'search': r'Магазин %_\ +7',
      'include_cancelled': 'true',
      'offset': '25',
      'limit': '25',
    });
    expect(page.total, 40);
    expect(page.documents.single.isPickup, isTrue);
    expect(page.documents.single.isActive, isFalse);
    expect(page.documents.single.purchasesCount, 3);
    expect(page.documents.single.totalAmount, 1234.56);
  });
}
