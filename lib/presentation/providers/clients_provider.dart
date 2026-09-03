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

    // Вспомогательная функция для расчета коэффициента просрочки (K)
    double getUrgencyCoefficient(Client client) {
      if (client.lastDeliveryDate == null) {
        return 999.0; // Максимальная срочность, если доставок никогда не было
      }

      // Считаем разницу в днях
      final differenceDays = now
          .difference(client.lastDeliveryDate!)
          .inDays;

      // Возвращаем коэффициент отношения к порогу засыпания
      return differenceDays / client.sleepingThresholdDays;
    }

    clients.sort((a, b) {
      final aOnCooldown = _isOnCooldown(a, now);
      final bOnCooldown = _isOnCooldown(b, now);

      // 1. Клиенты на кулдауне всегда в самом конце
      if (aOnCooldown != bOnCooldown) {
        return aOnCooldown ? 1 : -1;
      }

      // 2. Если оба на кулдауне — сначала тот, у кого он закончится раньше
      if (aOnCooldown && bOnCooldown) {
        return a.cooldownUntil!.compareTo(b.cooldownUntil!);
      }

      // 3. Для активных клиентов сортируем по коэффициенту срочности (чем больше K, тем выше)
      final aUrgency = getUrgencyCoefficient(a);
      final bUrgency = getUrgencyCoefficient(b);

      if (aUrgency != bUrgency) {
        return bUrgency.compareTo(aUrgency); // Сортировка по убыванию
      }

      // 4. Если коэффициенты равны, сортируем по имени
      return a.name.compareTo(b.name);
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

  Future<void> updateClientCooldown(int clientId, int weeks) async {
    try {
      // Высчитываем дату окончания кулдауна относительно текущего момента
      final cooldownDate = DateTime.now().add(Duration(days: weeks * 7));

      // Обновляем на "сервере" (в репозитории)
      final updatedClient = await _repository.updateCooldown(
          clientId, cooldownDate);

      // Обновляем локальный список в стейте провайдера
      _clients = _clients.map((client) {
        return client.id == clientId ? updatedClient : client;
      }).toList();

      // Уведомляем UI для перерисовки и пересортировки
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      // Здесь можно сгенерировать отдельный эвент ошибки для Снэкбара
      notifyListeners();
    }
  }


}
