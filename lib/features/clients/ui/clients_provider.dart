import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';

enum ClientStatus { initial, loading, success, failure }

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
      final differenceDays = now.difference(client.lastDeliveryDate!).inDays;
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
    // РЕЖИМ 2: Сортировка по времени создания, затем UUID
    // ----------------------------------------------------
    final allClients = [..._clients];
    allClients.sort(
      (a, b) {
        final date = b.createdAt.compareTo(a.createdAt);
        return date != 0 ? date : b.id.compareTo(a.id);
      },
    );
    return allClients;
  }

  Future<void> fetchClients() async {
    if (_status == ClientStatus.loading) {
      return;
    }

    final version = ++_fetchVersion;
    _status = ClientStatus.loading;
    _errorMessage = '';
    phoneError = null;

    notifyListeners();

    try {
      final loaded = await _repository.getAllClients();
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

  Future<bool> updateClientCooldown(String clientId, int weeks) async {
    try {
      // Высчитываем дату окончания кулдауна относительно текущего момента
      final cooldownDate = DateTime.now().add(Duration(days: weeks * 7));

      // Обновляем на "сервере" (в репозитории)
      final updatedClient = await _repository.updateCooldown(
        clientId,
        cooldownDate,
      );

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
      final request = UpdateClientRequest(
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

  Future<bool> deleteClient(String clientId) async {
    _errorMessage = '';
    phoneError = null;

    try {
      await _repository.deleteClient(clientId);

      _fetchVersion++;
      _clients = _clients.where((client) => client.id != clientId).toList();

      _status = ClientStatus.success;

      notifyListeners();
      return true;
    } catch (e) {
      _recordError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setClientActive(String id, bool active) async {
    _errorMessage = '';
    phoneError = null;
    try {
      final client = await _repository.updateClient(
        id,
        UpdateClientRequest(isActive: active),
      );
      _fetchVersion++;
      _clients = _clients.where((row) => row.id != id).toList();
      lastSavedClient = client;
      if (active) _clients = [client, ..._clients];
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
