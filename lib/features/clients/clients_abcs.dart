import 'package:mountain_fairytale/features/clients/data/clients_model.dart';

abstract interface class ClientDataSource {
  Future<List<Map<String, dynamic>>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  });
  Future<Map<String, dynamic>> getClientById(String id);
  Future<Map<String, dynamic>?> checkDuplicate(
    String name,
    String phone,
    String address,
  );
  Future<Map<String, dynamic>> createClient(Map<String, dynamic> json);
  Future<Map<String, dynamic>> patchClient(
    String id,
    Map<String, dynamic> json,
  );
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives({
    bool includeDeactivated = false,
  });
  Future<List<ClientDirectoryEntry>> getPaymentMethods({
    bool includeDeactivated = false,
  });
}

abstract interface class ClientRepository {
  Future<List<Client>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  });
  Future<Client> getClientById(String id);
  Future<Client> updateCooldown(String clientId, DateTime cooldownUntil);
  Future<Client?> checkDuplicate(String name, String phone, String address);
  Future<Client> createClient(CreateClientRequest request);
  Future<Client> updateClient(String id, UpdateClientRequest request);
  Future<void> deleteClient(String id);
  Future<List<ClientDirectoryEntry>> getSalesRepresentatives({
    bool includeDeactivated = false,
  });
  Future<List<ClientDirectoryEntry>> getPaymentMethods({
    bool includeDeactivated = false,
  });
}
