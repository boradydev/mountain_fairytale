import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';

abstract interface class ClientDataSource {
  Future<List<Map<String, dynamic>>> getAllClients();
  Future<Map<String, dynamic>> getClientById(int id);

  Future<Map<String, dynamic>> updateCooldown(int clientId,
      String cooldownUntilIso);
  Future<Map<String, dynamic>?> checkDuplicate(String name, String address);

  Future<Map<String, dynamic>> createClient(
      Map<String, dynamic> json); // Принимает JSON-карту
  Future<Map<String, dynamic>> patchClient(int id, Map<String, dynamic> json);
  Future<void> deleteClient(int id);
}

abstract interface class ClientRepository {
  Future<List<Client>> getAllClients();
  Future<Client> getClientById(int id);
  Future<Client> updateCooldown(int clientId, DateTime cooldownUntil);
  Future<Client?> checkDuplicate(String name, String address);

  Future<Client> createClient(CreateClientRequest request); // ИСПОРАВЛЕНО
  Future<Client> updateClient(int id,
      UpdateClientRequest request); // ИСПРАВЛЕНО
  Future<void> deleteClient(int id);
}
