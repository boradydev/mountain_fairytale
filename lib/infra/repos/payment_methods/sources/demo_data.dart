import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/payment_method_abcs.dart';

class DemoPaymentMethodDataSource implements PaymentMethodDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _cache;

  DemoPaymentMethodDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllPaymentMethods() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_cache != null) return _cache!;

    final jsonString = await _assetBundle.loadString(
      'assets/demo/payment_methods/payment_methods_data.json',
    );
    _cache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _cache!;
  }

  @override
  Future<Map<String, dynamic>> createPaymentMethod(
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_cache == null) await getAllPaymentMethods();

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
  Future<Map<String, dynamic>> patchPaymentMethod(
    int id,
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_cache == null) await getAllPaymentMethods();

    final index = _cache!.indexWhere((e) => e['id'] == id);
    if (index == -1) throw Exception('PaymentMethod with id $id not found');

    final Map<String, dynamic> updatedItem = Map<String, dynamic>.from(
      _cache![index],
    );

    json.forEach((key, value) {
      if (value != null) {
        updatedItem[key] = value;
      }
    });

    _cache![index] = updatedItem;
    return updatedItem;
  }

  @override
  Future<void> deletePaymentMethod(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_cache == null) await getAllPaymentMethods();
    _cache!.removeWhere((e) => e['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> getPaymentMethodById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_cache == null) await getAllPaymentMethods();
    return _cache!.firstWhere(
      (e) => e['id'] == id,
      orElse: () => throw Exception('PaymentMethod with id $id not found'),
    );
  }
}
