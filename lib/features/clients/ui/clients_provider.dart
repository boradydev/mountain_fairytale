import 'dart:async';
import 'dart:math' as math;

import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';

enum ClientStatus { initial, loading, success, failure }

enum ClientListMode { database, followUp }

/// Dashboard pages never populate or truncate the selector directory.
class DashboardClientsState {
  List<Client> clients = [];
  int total = 0;
  int offset = 0;
  int generation = 0;
  bool initialized = false;
  bool loading = false;
  String error = '';
  bool refreshFailed = false;
  double scrollOffset = 0;
  bool get hasMore => !initialized || offset < total;
}

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
    _resetDashboard(ClientListMode.database);
    notifyListeners();
    if (_dashboardStarted && _listMode == ClientListMode.database) {
      await loadDashboardClients();
    }
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
    if (_dashboardStarted && !dashboard.initialized) {
      unawaited(loadDashboardClients());
    }
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

  final _dashboard = {
    for (final mode in ClientListMode.values) mode: DashboardClientsState(),
  };
  bool _dashboardStarted = false;
  String _search = '';
  String get search => _search;
  DashboardClientsState get dashboard => _dashboard[_listMode]!;
  DashboardClientsState dashboardFor(ClientListMode mode) => _dashboard[mode]!;

  void _resetDashboard(ClientListMode mode) {
    final old = _dashboard[mode]!;
    old.generation++;
    _dashboard[mode] = DashboardClientsState();
  }

  Future<void> setSearch(String value) async {
    value = value.length > 500 ? value.substring(0, 500) : value;
    if (value == _search) return;
    _search = value;
    for (final mode in ClientListMode.values) {
      _resetDashboard(mode);
    }
    notifyListeners();
    if (_dashboardStarted) await loadDashboardClients();
  }

  Future<void> initializeDashboardClients() async {
    _dashboardStarted = true;
    await loadDashboardClients();
  }

  Future<ClientsPage<Client>> _page(ClientListMode mode, int offset) =>
      _repository.getClientsPage(
        offset: offset,
        limit: 25,
        search: _search,
        includeDeactivated: mode == ClientListMode.database && _showDeactivated,
        mode: mode == ClientListMode.database ? 'database' : 'follow_up',
      );

  Future<void> loadDashboardClients() async {
    final mode = _listMode;
    final state = _dashboard[mode]!;
    if (state.loading || !state.hasMore) return;
    final version = ++state.generation;
    state.loading = true;
    state.error = '';
    state.refreshFailed = false;
    notifyListeners();
    try {
      final page = await _page(mode, state.offset);
      if (version != state.generation) return;
      final byId = {for (final client in state.clients) client.id: client};
      for (final client in page.clients) {
        byId[client.id] = client;
      }
      state.clients = byId.values.toList();
      state.total = page.total;
      state.offset += page.clients.length;
      if (page.clients.isEmpty) state.offset = page.total;
      state.initialized = true;
    } catch (_) {
      if (version != state.generation) return;
      state.error = 'Не удалось загрузить клиентов. Повторите запрос.';
    } finally {
      if (version == state.generation) {
        state.loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _refreshDashboardMode(ClientListMode mode) async {
    final state = _dashboard[mode]!;
    if (state.loading) return false;
    final version = ++state.generation;
    final search = _search;
    final include = mode == ClientListMode.database && _showDeactivated;
    final target = math.max(25, state.offset);
    state.loading = true;
    notifyListeners();
    try {
      final rows = <Client>[];
      var total = 0;
      var offset = 0;
      do {
        final page = await _repository.getClientsPage(
          offset: offset,
          limit: 25,
          search: search,
          includeDeactivated: include,
          mode: mode == ClientListMode.database ? 'database' : 'follow_up',
        );
        if (version != state.generation) return false;
        rows.addAll(page.clients);
        total = page.total;
        offset += page.clients.length;
        if (page.clients.isEmpty) {
          offset = total;
          break;
        }
      } while (offset < target && offset < total);
      state.clients = {for (final row in rows) row.id: row}.values.toList();
      state.total = total;
      state.offset = offset;
      state.initialized = true;
      state.error = '';
      return true;
    } catch (_) {
      if (version == state.generation) {
        state.error = 'Не удалось обновить клиентов. Повторите запрос.';
        state.refreshFailed = true;
      }
      return false;
    } finally {
      if (version == state.generation) {
        state.loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> refreshDashboardClients() async {
    if (!_dashboardStarted) return true;
    final results = await Future.wait([
      for (final mode in ClientListMode.values)
        if (mode == _listMode || _dashboard[mode]!.initialized)
          _refreshDashboardMode(mode),
    ]);
    return results.every((success) => success);
  }

  Future<void> _clientChanged() async {
    for (final state in _dashboard.values) {
      state.generation++;
      state.loading = false;
    }
    await refreshDashboardClients();
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
      await _clientChanged();
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
    DeliveryAddress? deliveryAddress,
    String deliveryDetails = '',
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
        deliveryAddress: deliveryAddress,
        deliveryDetails: deliveryDetails,
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

      await _clientChanged();
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
    DeliveryAddress? deliveryAddress,
    String deliveryDetails = '',
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
            deliveryAddress: deliveryAddress,
            deliveryDetails: deliveryDetails,
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

      await _clientChanged();
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
      await _clientChanged();
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
    unawaited(_clientChanged());
    notifyListeners();
  }

  @override
  void dispose() {
    _fetchVersion++;
    for (final state in _dashboard.values) {
      state.generation++;
    }
    super.dispose();
  }
}
