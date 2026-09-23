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

/// Реализация репозитория.
class SalesRepresentativeClientRepositoryImpl
    implements SalesRepresentativeClientRepository {
  final SalesRepresentativeClientDataSource dataSource;

  SalesRepresentativeClientRepositoryImpl(this.dataSource);

  @override
  Future<List<SalesRepresentativeClient>> getClients({
    required int salesRepresentativeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    // Конвертируем DateTime в формат yyyy-MM-dd для DataSource
    // Используем split('T')[0], чтобы получить только дату из ISO строки
    final String fromStr = dateFrom.toIso8601String().split('T')[0];
    final String toStr = dateTo.toIso8601String().split('T')[0];

    final jsonList = await dataSource.getClients(
      salesRepresentativeId: salesRepresentativeId,
      dateFrom: fromStr,
      dateTo: toStr,
    );

    return jsonList
        .map((json) => SalesRepresentativeClient.fromJson(json))
        .toList();
  }

  @override
  Future<void> assignClientsToSalesRepresentative({
    required int fromId,
    required int toId,
  }) async {
    // Делегируем операцию в DataSource.
    // Логика получения имени нового представителя находится внутри DemoDataSource.
    await dataSource.assignClientsToSalesRepresentative(
      fromId: fromId,
      toId: toId,
    );
  }

  @override
  Future<void> clearSalesRepresentativeClients({
    required int salesRepresentativeId,
  }) async {
    await dataSource.clearSalesRepresentativeClients(
      salesRepresentativeId: salesRepresentativeId,
    );
  }
}
