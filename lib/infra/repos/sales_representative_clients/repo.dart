import 'package:mountain_fairytale/infra/repos/sales_representative_clients/models/sales_representative_client_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative_client.dart';

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
