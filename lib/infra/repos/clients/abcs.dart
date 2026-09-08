import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';

abstract interface class ClientRepository {
  Future<List<Client>> getAllClients();
  Future<Client> updateCooldown(int clientId, DateTime cooldownUntil);

  Future<Client?> checkDuplicate(String name, String address);

  // Новый контракт в репозитории
  Future<Client> createClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
  });
}