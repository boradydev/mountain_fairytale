import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos.dart';

class DemoSalesRepresentativeDataSource
    implements SalesRepresentativeDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _cache;

  DemoSalesRepresentativeDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllSalesRepresentatives() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_cache != null) return _cache!;

    final jsonString = await _assetBundle.loadString(
      'assets/demo/sales_representatives/sales_representatives_data.json',
    );
    _cache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _cache!;
  }

  @override
  Future<Map<String, dynamic>> createSalesRepresentative(
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_cache == null) await getAllSalesRepresentatives();

    final newId = _cache!.isEmpty
        ? 1
        : _cache!
                  .map((e) => int.parse(e['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final newItem = {...json, 'id': newId};
    _cache!.insert(0, newItem);
    return newItem;
  }

  @override
  Future<Map<String, dynamic>> patchSalesRepresentative(
    int id,
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_cache == null) await getAllSalesRepresentatives();

    final index = _cache!.indexWhere((e) => e['id'] == id);
    if (index == -1) {
      throw Exception('SalesRepresentative with id $id not found');
    }

    // Хак бэкенда: создаем копию старого состояния
    final Map<String, dynamic> updatedItem = Map<String, dynamic>.from(
      _cache![index],
    );

    // Переносим только НЕ-null поля из PATCH запроса
    json.forEach((key, value) {
      if (value != null) {
        updatedItem[key] = value;
      }
    });

    _cache![index] = updatedItem;
    return updatedItem;
  }

  @override
  Future<void> deleteSalesRepresentative(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_cache == null) await getAllSalesRepresentatives();
    _cache!.removeWhere((e) => e['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> getSalesRepresentativeById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_cache == null) await getAllSalesRepresentatives();
    return _cache!.firstWhere(
      (e) => e['id'] == id,
      orElse: () =>
          throw Exception('SalesRepresentative with id $id not found'),
    );
  }
}
