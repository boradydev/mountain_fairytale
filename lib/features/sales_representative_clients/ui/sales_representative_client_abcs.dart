import 'package:mountain_fairytale/infra/repos/sales_representative_clients/models/sales_representative_client_model.dart';

/// Контракт источника данных для клиентов торгового представителя.
/// Работает с сырыми данными (Map), имитируя API или JSON-файлы.
abstract interface class SalesRepresentativeClientDataSource {
  Future<List<Map<String, dynamic>>> getClients({
    required int salesRepresentativeId,
    required String dateFrom,
    required String dateTo,
  });

  Future<void> assignClientsToSalesRepresentative({
    required int fromId,
    required int toId,
  });

  Future<void> clearSalesRepresentativeClients({
    required int salesRepresentativeId,
  });
}

/// Контракт репозитория для управления статистикой и привязкой клиентов.
/// Преобразует сырые данные из DataSource в типизированные модели.
abstract interface class SalesRepresentativeClientRepository {
  Future<List<SalesRepresentativeClient>> getClients({
    required int salesRepresentativeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  });

  Future<void> assignClientsToSalesRepresentative({
    required int fromId,
    required int toId,
  });

  Future<void> clearSalesRepresentativeClients({
    required int salesRepresentativeId,
  });
}
