import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';

enum ClientStatus { initial, loading, success, failure }

class ClientsProvider extends ChangeNotifier {
  final ClientRepository _repository;

  ClientsProvider(this._repository);

  List<Client> _clients = const [];

  ClientStatus _status = ClientStatus.initial;
  String _errorMessage = '';

  List<Client> get clients => _clients;

  ClientStatus get status => _status;

  String get errorMessage => _errorMessage;

  bool get isLoading => _status == ClientStatus.loading;

  bool get hasError => _status == ClientStatus.failure;

  bool get isEmpty => _status == ClientStatus.success && _clients.isEmpty;

  List<Client> get sortedClients {
    final clients = [..._clients];

    final now = DateTime.now();

    clients.sort((a, b) {
      final aOnCooldown = _isOnCooldown(a, now);
      final bOnCooldown = _isOnCooldown(b, now);

      // Клиенты на cooldown всегда в конце.
      if (aOnCooldown != bOnCooldown) {
        return aOnCooldown ? 1 : -1;
      }

      // Если оба на cooldown — сначала тот,
      // у кого cooldown закончится раньше.
      if (aOnCooldown && bOnCooldown) {
        return a.cooldownUntil!.compareTo(b.cooldownUntil!);
      }

      // Клиенты без доставки вообще — самые приоритетные.
      if (a.lastDeliveryDate == null && b.lastDeliveryDate != null) {
        return -1;
      }

      if (a.lastDeliveryDate != null && b.lastDeliveryDate == null) {
        return 1;
      }

      // Если у обоих нет доставки — порядок по имени.
      if (a.lastDeliveryDate == null && b.lastDeliveryDate == null) {
        return a.name.compareTo(b.name);
      }

      // Чем старше последняя доставка,
      // тем выше клиент в списке.
      return a.lastDeliveryDate!.compareTo(b.lastDeliveryDate!);
    });

    return clients;
  }

  bool _isOnCooldown(Client client, DateTime now) {
    final cooldownUntil = client.cooldownUntil;

    if (cooldownUntil == null) {
      return false;
    }

    return cooldownUntil.isAfter(now);
  }

  Future<void> fetchClients() async {
    if (_status == ClientStatus.loading) {
      return;
    }

    _status = ClientStatus.loading;
    _errorMessage = '';

    notifyListeners();

    try {
      _clients = await _repository.getAllClients();

      _status = ClientStatus.success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ClientStatus.failure;
    } finally {
      notifyListeners();
    }
  }
}
