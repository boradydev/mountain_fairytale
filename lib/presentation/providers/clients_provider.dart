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

  // Новый стейт: показывать только просроченных?
  bool _showOnlySleeping = false;

  List<Client> get clients => _clients;
  ClientStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == ClientStatus.loading;
  bool get hasError => _status == ClientStatus.failure;
  bool get isEmpty => _status == ClientStatus.success && _clients.isEmpty;

  // Геттер для чтения состояния фильтра в UI
  bool get showOnlySleeping => _showOnlySleeping;

  /// Переключатель фильтра
  void toggleSleepingFilter() {
    _showOnlySleeping = !_showOnlySleeping;
    notifyListeners(); // Мгновенно перерисовываем UI с новой логикой
  }

  /// Универсальный геттер, который теперь учитывает активный режим
  List<Client> get sortedClients {
    final now = DateTime.now();

    // Вспомогательная функция для расчета коэффициента просрочки (K)
    double getUrgencyCoefficient(Client client) {
      if (client.lastDeliveryDate == null) return 999.0;
      final differenceDays = now
          .difference(client.lastDeliveryDate!)
          .inDays;
      return differenceDays / client.sleepingThresholdDays;
    }

    // Вспомогательная функция проверки: просрочен ли клиент? (K >= 1.0)
    bool isSleeping(Client client) {
      // Если клиент на кулдауне, менеджер его уже обработал — он временно не считается "активно засыпающим"
      final cooldownUntil = client.cooldownUntil;
      if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
        return false;
      }
      return getUrgencyCoefficient(client) >= 1.0;
    }

    // ----------------------------------------------------
    // РЕЖИМ 1: Показываем ТОЛЬКО просроченных клиентов
    // ----------------------------------------------------
    if (_showOnlySleeping) {
      // Сначала фильтруем: оставляем только тех, кто реально спит
      final filtered = _clients.where(isSleeping).toList();

      // Сортируем их по критичности (чем больше K, тем выше)
      filtered.sort((a, b) {
        final aUrgency = getUrgencyCoefficient(a);
        final bUrgency = getUrgencyCoefficient(b);
        if (aUrgency != bUrgency) return bUrgency.compareTo(aUrgency);
        return a.name.compareTo(b.name);
      });

      return filtered;
    }

    // ----------------------------------------------------
    // РЕЖИМ 2: Обычный режим (Сортировка по ID от новых к старым)
    // ----------------------------------------------------
    final allClients = [..._clients];
    allClients.sort((a, b) =>
        b.id.compareTo(a.id)); // Новые (больший ID) будут сверху
    return allClients;
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
