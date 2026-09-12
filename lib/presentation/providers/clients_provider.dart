import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/client_contracts.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative.dart';

enum ClientStatus { initial, loading, success, failure }

class ClientsProvider extends ChangeNotifier {
  final ClientRepository _repository;
  final SalesRepresentativeRepository _salesRepRepo;

  ClientsProvider(this._repository, this._salesRepRepo);

  List<Client> _clients = const [];
  List<SalesRepresentative> _salesRepresentatives = const [];

  List<SalesRepresentative> get salesRepresentatives => _salesRepresentatives;

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

  Future<Client?> checkClientDuplicate(String name, String address) async {
    try {
      return await _repository.checkDuplicate(name, address);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }


  Future<bool> addClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
    int? salesRepId,
    String? salesRepName,
  }) async {
    _status = ClientStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final request = CreateClientRequest(
        name: name,
        phone: phone,
        address: address,
        sleepingThresholdDays: thresholdDays,
        salesRepresentativeId: salesRepId,
        salesRepresentativeName: salesRepName,
      );

      final newClient = await _repository.createClient(request);

      _clients = [newClient, ..._clients];
      _status = ClientStatus.success;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ClientStatus.failure;

      notifyListeners();
      return false;
    }
  }

  Future<bool> updateClient({
    required int clientId,
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
    int? salesRepId, // <-- Добавлено
    String? salesRepName, // <-- Добавлено
  }) async {
    _errorMessage = '';

    try {
      final request = UpdateClientRequest(
        name: name,
        phone: phone,
        address: address,
        sleepingThresholdDays: thresholdDays,
        salesRepresentativeId: salesRepId,
        // <-- Добавлено
        salesRepresentativeName: salesRepName, // <-- Добавлено
      );

      final updatedClient = await _repository.updateClient(
        clientId,
        request,
      );

      _clients = _clients.map((client) {
        return client.id == clientId ? updatedClient : client;
      }).toList();

      _status = ClientStatus.success;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteClient(int clientId) async {
    _errorMessage = '';

    try {
      await _repository.deleteClient(clientId);

      _clients = _clients
          .where((client) => client.id != clientId)
          .toList();

      _status = ClientStatus.success;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchSalesRepresentatives() async {
    try {
      _salesRepresentatives = await _salesRepRepo.getAllSalesRepresentatives();
      notifyListeners();
    } catch (_) {}
  }

  Future<SalesRepresentative?> addSalesRepresentative(String name,
      String phone) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return null;
    try {
      final request = CreateSalesRepresentativeRequest(
          name: normalizedName, phone: phone.trim());
      final created = await _salesRepRepo.createSalesRepresentative(request);
      _salesRepresentatives = [created, ..._salesRepresentatives];
      notifyListeners();
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateSalesRepresentative(int id, String name,
      String phone) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;
    try {
      final request = UpdateSalesRepresentativeRequest(
          name: normalizedName, phone: phone.trim());
      final updated = await _salesRepRepo.updateSalesRepresentative(
          id, request);
      _salesRepresentatives =
          _salesRepresentatives.map((r) => r.id == id ? updated : r).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSalesRepresentative(int id) async {
    try {
      await _salesRepRepo.deleteSalesRepresentative(id);
      _salesRepresentatives =
          _salesRepresentatives.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SalesRepresentative?> checkSalesRepDuplicate(String name) async {
    try {
      return await _salesRepRepo.checkDuplicate(name);
    } catch (_) {
      return null;
    }
  }

}
