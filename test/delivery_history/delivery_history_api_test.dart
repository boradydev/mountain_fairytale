import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_history/ui/client_delivery_card.dart';
import 'package:mountain_fairytale/shared/widgets/document_summary_card.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/core/network/api_client.dart';
import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_api_repo.dart';

class _ApiClient implements ApiClient {
  Uri? request;
  @override
  Future<Map<String, dynamic>> get(String path) async {
    request = Uri.parse(path);
    if (request!.path == '/protected/client-delivery-history') {
      return {
        'offset': 50,
        'limit': 50,
        'total': 51,
        'data': {
          'deliveries': [
            {
              'pointId': 'point',
              'clientId': 'client',
              'deliveryDocumentId': 'route',
              'clientName': 'Saved name',
              'address': 'Saved address — details',
              'clientAddress': 'Saved address',
              'deliveryDetails': 'details',
              'phone': '123',
              'salesRepresentativeId': 'rep',
              'salesRepresentativeName': 'Inactive representative',
              'plannedDate': '2026-11-03',
              'createdAt': '2026-11-02T12:30:00',
              'totalAmount': '1.01',
              'documentTotalAmount': '19.99',
              'clientsCount': 3,
              'items': [
                {
                  'itemId': 'item',
                  'productId': 'product',
                  'productName': 'Saved product',
                  'quantity': 1,
                  'price': '1.005',
                  'amount': '1.01',
                  'isFreePrice': true,
                  'driverNote': 'Note',
                },
              ],
            },
          ],
        },
      };
    }
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
  testWidgets(
    'compact card hides count while API retains all three route clients',
    (tester) async {
      final api = _ApiClient();
      final page = await ApiDeliveryHistoryRepository(api).getClientHistory(
        dateFrom: DateTime(2026, 10, 5),
        dateTo: DateTime(2026, 11, 3),
        search: 'Saved name',
        offset: 0,
        limit: 50,
      );
      expect(api.request!.queryParameters['search'], 'Saved name');
      expect(page.deliveries, hasLength(1));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                ClientDeliveryCard(
                  delivery: page.deliveries.single,
                  onOpen: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byType(DocumentSummaryCard);
      expect(
        find.descendant(of: card, matching: find.text('Клиентов:')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('3')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'client API reads point identity, snapshots and route total separately',
    () async {
      final client = _ApiClient();
      final page = await ApiDeliveryHistoryRepository(client).getClientHistory(
        dateFrom: DateTime(2026, 10, 5),
        dateTo: DateTime(2026, 11, 3),
        search: r'%_\ +7',
        offset: 50,
        limit: 50,
      );
      expect(client.request!.queryParameters, {
        'date_from': '2026-10-05',
        'date_to': '2026-11-03',
        'search': r'%_\ +7',
        'offset': '50',
        'limit': '50',
      });
      expect(page.total, 51);
      final point = page.deliveries.single;
      expect(point.pointId, 'point');
      expect(point.clientName, 'Saved name');
      expect(point.document.id, 'route');
      expect(point.document.totalAmount, 19.99);
      expect(point.document.clientsCount, 3);
      expect(point.document.createdAt, DateTime(2026, 11, 2, 12, 30));
      expect(point.totalAmount, 1.01);
      expect(point.salesRepresentativeId, 'rep');
      expect(point.items.single.itemId, 'item');
      expect(point.items.single.isFreePrice, true);
    },
  );
  test('documents filter excludes empty client search', () async {
    final client = _ApiClient();
    await ApiDeliveryHistoryRepository(client).getHistory(
      dateFrom: DateTime(2026, 10, 5),
      dateTo: DateTime(2026, 11, 3),
      search: '',
      includeCancelled: false,
      documentType: 'pickup_sheet',
      offset: 0,
      limit: 50,
    );
    expect(client.request!.queryParameters.containsKey('search'), false);
    expect(client.request!.queryParameters['document_type'], 'pickup_sheet');
  });
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
      'document_type': 'all',
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
