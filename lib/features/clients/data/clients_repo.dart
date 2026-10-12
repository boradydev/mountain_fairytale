import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientDataSource dataSource;
  ClientRepositoryImpl(this.dataSource);
  @override
  Future<List<Client>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  }) async => (await dataSource.getAllClients(
    search: search,
    includeDeactivated: includeDeactivated,
  )).map(Client.fromJson).toList();
  @override
  Future<Client> getClientById(String id) async =>
      Client.fromJson(await dataSource.getClientById(id));
  @override
  Future<Client> updateCooldown(String clientId, DateTime cooldownUntil) =>
      updateClient(clientId, UpdateClientRequest(cooldownUntil: cooldownUntil));
  @override
  Future<Client?> checkDuplicate(
    String name,
    String phone,
    String address,
  ) async {
    final json = await dataSource.checkDuplicate(name, phone, address);
    return json == null ? null : Client.fromJson(json);
  }

  @override
  Future<Client> createClient(CreateClientRequest request) async =>
      Client.fromJson(await dataSource.createClient(request.toJson()));
  @override
  Future<Client> updateClient(String id, UpdateClientRequest request) async =>
      Client.fromJson(await dataSource.patchClient(id, request.toJson()));
  @override
  Future<void> deleteClient(String id) async {
    await updateClient(id, const UpdateClientRequest(isActive: false));
  }

  @override
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives() =>
      dataSource.getSalesRepresentatives();
  @override
  Future<List<ClientDirectoryEntry>> getPaymentMethods() =>
      dataSource.getPaymentMethods();
}
