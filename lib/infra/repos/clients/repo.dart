import 'package:mountain_fairytale/core/repos/client_contracts.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientDataSource dataSource;

  ClientRepositoryImpl(this.dataSource);

  @override
  Future<List<Client>> getAllClients() async {
    final jsonList = await dataSource.getAllClients();
    return jsonList.map(Client.fromJson).toList();
  }

  @override
  Future<Client> getClientById(int id) async {
    final json = await dataSource.getClientById(id);
    return Client.fromJson(json);
  }

  @override
  Future<Client> updateCooldown(int clientId, DateTime cooldownUntil) async {
    // Переводим DateTime в ISO-строку, так как HTTP-клиенты/JSON работают со строками
    final String isoDate = cooldownUntil.toIso8601String();

    // Отправляем запрос в DataSource
    final updatedJson = await dataSource.updateCooldown(clientId, isoDate);

    // Маппим результат обратно в строго типизированную модель
    return Client.fromJson(updatedJson);
  }

  @override
  Future<Client?> checkDuplicate(String name, String address) async {
    final json = await dataSource.checkDuplicate(name, address);
    if (json == null) return null;
    return Client.fromJson(json);
  }

  @override
  Future<Client> createClient(CreateClientRequest request) async {
    final json = await dataSource.createClient(request.toJson());
    return Client.fromJson(json);
  }

  @override
  Future<Client> updateClient(int id, UpdateClientRequest request) async {
    final updatedJson = await dataSource.patchClient(id, request.toJson());
    return Client.fromJson(updatedJson);
  }

  @override
  Future<void> deleteClient(int id) async {
    await dataSource.deleteClient(id);
  }
}
