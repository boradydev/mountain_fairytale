import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';

enum ClientStatus { initial, loading, success, failure }

enum ClientListMode { database, followUp }

class ClientsProvider extends SafeChangeNotifier {
  final ClientRepository _repository;

  ClientsProvider(this._repository);

  List<Client> _clients = const [];

  ClientStatus _status = ClientStatus.initial;
  String _errorMessage = '';
  String? phoneError;
  Client? lastSavedClient;
  int _fetchVersion = 0;

  void clearPhoneError() {
    phoneError = null;
  }

  void _recordError(Object error) {
    if (error is ApiException && error.statusCode == 409) {
      phoneError = 'Телефон уже используется другим клиентом';
      _errorMessage = '';
    } else {
      _errorMessage = 'Не удалось выполнить запрос. Повторите попытку.';
    }
  }

  ClientListMode _listMode = ClientListMode.database;
  bool _showDeactivated = false;
  bool get showDeactivated => _showDeactivated;

  Future<void> setShowDeactivated(bool value) async {
    if (_showDeactivated == value) return;
    _showDeactivated = value;
    await fetchClients(force: true);
  }

  List<Client> get clients => _clients;
  ClientStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == ClientStatus.loading;
  bool get hasError => _status == ClientStatus.failure;
  bool get isEmpty => _status == ClientStatus.success && _clients.isEmpty;

  ClientListMode get listMode => _listMode;

  void setListMode(ClientListMode mode) {
    if (_listMode == mode) return;
    _listMode = mode;
    notifyListeners();
  }

  /// Универсальный геттер, который теперь учитывает активный режим
  List<Client> get sortedClients {
    final now = DateTime.now();

    // Вспомогательная функция для расчета коэффициента просрочки (K)
    double getUrgencyCoefficient(Client client) {
      if (client.lastOrderDate == null) return double.infinity;
      final differenceDays = client.daysSinceLastOrder(now)!;
      return client.sleepingThresholdDays == 0
          ? double.infinity
          : differenceDays / client.sleepingThresholdDays;
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
    if (_listMode == ClientListMode.followUp) {
      // Сначала фильтруем: оставляем только тех, кто реально спит
      final filtered = _clients
          .where((client) => client.isActive && isSleeping(client))
          .toList();

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
    // РЕЖИМ 2: Сортировка по времени создания, затем UUID
    // ----------------------------------------------------
    final allClients = _clients
        .where((client) => client.isActive || _showDeactivated)
        .toList();
    allClients.sort(
      (a, b) {
        final date = b.createdAt.compareTo(a.createdAt);
        return date != 0 ? date : b.id.compareTo(a.id);
      },
    );
    return allClients;
  }

  Future<void> fetchClients({bool force = false}) async {
    if (_status == ClientStatus.loading && !force) {
      return;
    }

    final version = ++_fetchVersion;
    _status = ClientStatus.loading;
    _errorMessage = '';
    phoneError = null;

    notifyListeners();

    try {
      final loaded = await _repository.getAllClients(
        includeDeactivated: _showDeactivated,
      );
      if (version != _fetchVersion) return;
      _clients = loaded;

      _status = ClientStatus.success;
    } catch (e) {
      if (version != _fetchVersion) return;
      _recordError(e);
      _status = ClientStatus.failure;
    } finally {
      if (version == _fetchVersion) notifyListeners();
    }
  }

  Future<bool> updateClientCooldown(String clientId, int weeks) {
    final now = DateTime.now();
    final cooldownDate = DateTime(now.year, now.month, now.day + weeks * 7);
    return _changeClientCooldown(clientId, cooldownDate);
  }

  Future<bool> resetClientCooldown(String clientId) =>
      _changeClientCooldown(clientId, null);

  Future<bool> refreshDashboardClients() async {
    if (isLoading) return false;
    final version = ++_fetchVersion;
    try {
      final loaded = await _repository.getAllClients(
        includeDeactivated: _showDeactivated,
      );
      if (version != _fetchVersion) return false;
      _clients = loaded;
      _status = ClientStatus.success;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _changeClientCooldown(
    String clientId,
    DateTime? cooldownDate,
  ) async {
    _errorMessage = '';
    phoneError = null;
    try {
      final updatedClient = cooldownDate == null
          ? await _repository.updateClient(
              clientId,
              const UpdateClientRequest(cooldownUntil: null),
            )
          : await _repository.updateCooldown(clientId, cooldownDate);

      // Обновляем локальный список в стейте провайдера
      _fetchVersion++;
      lastSavedClient = updatedClient;
      _clients = _clients.map((client) {
        return client.id == clientId ? updatedClient : client;
      }).toList();

      _status = ClientStatus.success;
      // Уведомляем UI для перерисовки и пересортировки
      notifyListeners();
      return true;
    } catch (e) {
      _recordError(e);
      // Здесь можно сгенерировать отдельный эвент ошибки для Снэкбара
      notifyListeners();
      return false;
    }
  }

  Future<Client?> checkClientDuplicate(
    String name,
    String phone,
    String address,
  ) => _repository.checkDuplicate(name, phone, address);

  Future<List<ClientDirectoryEntry>> getSalesRepresentatives({
    bool includeDeactivated = false,
  }) => _repository.getSalesRepresentatives(
    includeDeactivated: includeDeactivated,
  );
  Future<List<ClientDirectoryEntry>> getPaymentMethods({
    bool includeDeactivated = false,
  }) => _repository.getPaymentMethods(includeDeactivated: includeDeactivated);
  Future<List<Client>> searchClients(
    String search, {
    bool includeDeactivated = false,
  }) => _repository.getAllClients(
    search: search,
    includeDeactivated: includeDeactivated,
  );

  Future<bool> addClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
    String? salesRepId,
    String? paymentMethodId,
    DateTime? cooldownUntil,
  }) async {
    _errorMessage = '';
    phoneError = null;
    notifyListeners();

    try {
      final request = CreateClientRequest(
        name: name,
        phone: phone,
        address: address,
        sleepingThresholdDays: thresholdDays,
        salesRepresentativeId: salesRepId,
        defaultPaymentMethodId: paymentMethodId,
        cooldownUntil: cooldownUntil,
      );

      final newClient = await _repository.createClient(request);

      _fetchVersion++;
      lastSavedClient = newClient;
      _clients = [newClient, ..._clients];
      _status = ClientStatus.success;

      notifyListeners();
      return true;
    } catch (e) {
      _recordError(e);

      notifyListeners();
      return false;
    }
  }

  Future<bool> updateClient({
    required String clientId,
    UpdateClientRequest? changes,
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
    String? salesRepId,
    String? paymentMethodId,
    DateTime? cooldownUntil,
  }) async {
    _errorMessage = '';
    phoneError = null;

    try {
      final request =
          changes ??
          UpdateClientRequest(
            name: name,
            phone: phone,
            address: address,
            sleepingThresholdDays: thresholdDays,
            salesRepresentativeId: salesRepId,

            defaultPaymentMethodId: paymentMethodId,
            cooldownUntil: cooldownUntil,
          );

      final updatedClient = await _repository.updateClient(
        clientId,
        request,
      );

      _fetchVersion++;
      lastSavedClient = updatedClient;
      _clients = _clients.map((client) {
        return client.id == clientId ? updatedClient : client;
      }).toList();

      _status = ClientStatus.success;

      notifyListeners();
      return true;
    } catch (e) {
      _recordError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteClient(String clientId) =>
      setClientActive(clientId, false);

  Future<bool> setClientActive(String id, bool active) async {
    _errorMessage = '';
    phoneError = null;
    try {
      final client = await _repository.updateClient(
        id,
        UpdateClientRequest(isActive: active),
      );
      _fetchVersion++;
      final exists = _clients.any((row) => row.id == id);
      _clients = exists
          ? _clients.map((row) => row.id == id ? client : row).toList()
          : [client, ..._clients];
      lastSavedClient = client;
      _status = ClientStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _recordError(e);
      notifyListeners();
      return false;
    }
  }

  void syncUpdatedClient(Client updatedClient) {
    _fetchVersion++;
    _status = ClientStatus.success;
    _clients = _clients.map((client) {
      return client.id == updatedClient.id ? updatedClient : client;
    }).toList();
    notifyListeners();
  }
}
