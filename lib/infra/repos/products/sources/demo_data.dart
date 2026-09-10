import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/product_contracts.dart';

class DemoProductDataSource implements ProductDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _productsCache;

  DemoProductDataSource({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_productsCache != null) return _productsCache!;
    final jsonString = await _assetBundle.loadString(
        'assets/demo/products/products_data.json');
    _productsCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _productsCache!;
  }

  @override
  Future<Map<String, dynamic>> getProductById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_productsCache == null) await getAllProducts();
    return _productsCache!.firstWhere((e) => e['id'] == id,
        orElse: () => throw Exception('Product not found'));
  }

  @override
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> json) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_productsCache == null) await getAllProducts();
    final newId = _productsCache!.isEmpty ? 1 : _productsCache!.map((e) =>
        int.parse(e['id'].toString())).reduce((a, b) => a > b ? a : b) + 1;
    final newItem = {...json, 'id': newId};
    _productsCache!.insert(0, newItem);
    return newItem;
  }

  @override
  Future<Map<String, dynamic>> patchProduct(int id,
      Map<String, dynamic> json) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_productsCache == null) await getAllProducts();
    final index = _productsCache!.indexWhere((e) => e['id'] == id);
    if (index == -1) throw Exception('Product not found');
    final updated = Map<String, dynamic>.from(_productsCache![index]);
    json.forEach((key, value) {
      if (value != null) updated[key] = value;
    });
    _productsCache![index] = updated;
    return updated;
  }

  @override
  Future<void> deleteProduct(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_productsCache == null) await getAllProducts();
    _productsCache!.removeWhere((e) => e['id'] == id);
  }
}
