import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_clients/models/sales_representative_client_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative_client.dart';

enum SalesRepClientsStatus { initial, loading, success, failure }

class SalesRepresentativeClientsProvider extends ChangeNotifier {
  final SalesRepresentativeClientRepository _repository;

  SalesRepresentativeClientsProvider(this._repository);

  SalesRepClientsStatus _status = SalesRepClientsStatus.initial;
  List<SalesRepresentativeClient> _clients = [];
  String _searchQuery = '';

  int? _currentRepresentativeId;
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  SalesRepClientsStatus get status => _status;
  List<SalesRepresentativeClient> get clients => _clients;
  int? get currentRepresentativeId => _currentRepresentativeId;
  DateTime get dateFrom => _dateFrom;
  DateTime get dateTo => _dateTo;

  List<SalesRepresentativeClient> get filteredClients {
    if (_searchQuery.isEmpty) return _clients;
    final query = _searchQuery.toLowerCase();
    return _clients
        .where(
          (c) =>
              c.clientName.toLowerCase().contains(query) ||
              c.phone.toLowerCase().contains(query),
        )
        .toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> selectRepresentative(int id, DateTime from, DateTime to) async {
    _currentRepresentativeId = id;
    _dateFrom = from;
    _dateTo = to;
    await fetchClients();
  }

  Future<void> fetchClients() async {
    if (_currentRepresentativeId == null) return;

    _status = SalesRepClientsStatus.loading;
    notifyListeners();

    try {
      _clients = await _repository.getClients(
        salesRepresentativeId: _currentRepresentativeId!,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      _status = SalesRepClientsStatus.success;
    } catch (e) {
      _status = SalesRepClientsStatus.failure;
    }
    notifyListeners();
  }

  Future<void> assignClientsTo(int toId) async {
    if (_currentRepresentativeId == null) return;

    _status = SalesRepClientsStatus.loading;
    notifyListeners();

    try {
      await _repository.assignClientsToSalesRepresentative(
        fromId: _currentRepresentativeId!,
        toId: toId,
      );
      await fetchClients();
    } catch (e) {
      _status = SalesRepClientsStatus.failure;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearRepresentative() async {
    if (_currentRepresentativeId == null) return;

    _status = SalesRepClientsStatus.loading;
    notifyListeners();

    try {
      await _repository.clearSalesRepresentativeClients(
        salesRepresentativeId: _currentRepresentativeId!,
      );
      await fetchClients();
    } catch (e) {
      _status = SalesRepClientsStatus.failure;
      notifyListeners();
      rethrow;
    }
  }
}
