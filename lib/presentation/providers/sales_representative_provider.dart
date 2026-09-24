import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative.dart';

class SalesRepresentativeProvider extends ChangeNotifier {
  final SalesRepresentativeRepository _repository;

  SalesRepresentativeProvider(this._repository);

  List<SalesRepresentative> _salesRepresentatives = const [];
  List<SalesRepresentative> get salesRepresentatives => _salesRepresentatives;

  Future<void> fetchSalesRepresentatives() async {
    try {
      _salesRepresentatives = await _repository.getAllSalesRepresentatives();
      notifyListeners();
    } catch (_) {}
  }

  Future<SalesRepresentative?> addSalesRepresentative(
    String name,
    String phone,
    double commissionPercent,
  ) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return null;
    try {
      final request = CreateSalesRepresentativeRequest(
        name: normalizedName,
        phone: phone.trim(),
        commissionPercent: commissionPercent,
      );
      final created = await _repository.createSalesRepresentative(request);
      _salesRepresentatives = [created, ..._salesRepresentatives];
      notifyListeners();
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateSalesRepresentative(
    int id,
    String name,
    String phone,
    double commissionPercent,
  ) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;
    try {
      final request = UpdateSalesRepresentativeRequest(
        name: normalizedName,
        phone: phone.trim(),
        commissionPercent: commissionPercent,
      );
      final updated = await _repository.updateSalesRepresentative(id, request);
      _salesRepresentatives = _salesRepresentatives
          .map((r) => r.id == id ? updated : r)
          .toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSalesRepresentative(int id) async {
    try {
      await _repository.deleteSalesRepresentative(id);
      _salesRepresentatives = _salesRepresentatives
          .where((r) => r.id != id)
          .toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SalesRepresentative?> checkSalesRepDuplicate(String name) async {
    try {
      return await _repository.checkDuplicate(name);
    } catch (_) {
      return null;
    }
  }
}
