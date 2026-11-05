import 'package:mountain_fairytale/features/delivery_history/data/delivery_history_model.dart';

abstract interface class DeliveryHistoryRepository {
  Future<DeliveryHistoryPage> getHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String search,
    required bool includeCancelled,
    required int offset,
    required int limit,
    String documentType = 'all',
  });
  Future<ClientDeliveryHistoryPage> getClientHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String search,
    required int offset,
    required int limit,
  });
}
