import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/data/client_latest_order.dart';

class ClientsPage<T> {
  final List<T> clients;
  final int total;
  const ClientsPage(this.clients, this.total);
}

abstract interface class ClientDataSource {
  Future<ClientsPage<Map<String, dynamic>>> getClientsPage({
    int offset = 0,
    int limit = 25,
    String? search,
    bool includeDeactivated = false,
    String mode = 'database',
  });
  Future<List<Map<String, dynamic>>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  });
  Future<Map<String, dynamic>> getClientById(String id);
  Future<Map<String, dynamic>?> getLatestOrder(String clientId);
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
  Future<ClientsPage<Client>> getClientsPage({
    int offset = 0,
    int limit = 25,
    String? search,
    bool includeDeactivated = false,
    String mode = 'database',
  });
  Future<List<Client>> getAllClients({
    String? search,
    bool includeDeactivated = false,
  });
  Future<Client> getClientById(String id);
  Future<ClientLatestOrder?> getLatestOrder(String clientId);
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
