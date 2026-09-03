import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';

abstract interface class ClientRepository {
  Future<List<Client>> getAllClients();

  // Добавляем контракт на обновление кулдауна
  Future<Client> updateCooldown(int clientId, DateTime cooldownUntil);
}
