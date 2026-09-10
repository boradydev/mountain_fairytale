import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';

abstract interface class ClientDataSource {
  Future<List<Map<String, dynamic>>> getAllClients(); // Без пагинации
  Future<Map<String, dynamic>> getClientById(int id);

  Future<Map<String, dynamic>> updateCooldown(
    int clientId,
    String cooldownUntilIso,
  );

  Future<Map<String, dynamic>?> checkDuplicate(String name, String address);

  Future<Map<String, dynamic>> createClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
  });

  Future<Map<String, dynamic>> patchClient(int id, Map<String, dynamic> json);

  Future<void> deleteClient(int id);
}

abstract interface class ClientRepository {
  Future<List<Client>> getAllClients(); // Без пагинации
  Future<Client> getClientById(int id);

  Future<Client> updateCooldown(int clientId, DateTime cooldownUntil);

  Future<Client?> checkDuplicate(String name, String address);

  Future<Client> createClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
  });

  Future<Client> updateClient(int id, Map<String, dynamic> json);

  Future<void> deleteClient(int id);
}
