import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';

class DemoProductDataSource implements ProductDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _productsCache;

  DemoProductDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  Future<void> _load() async {
    if (_productsCache != null) return;
    await Future.delayed(const Duration(milliseconds: 40));
    final jsonString = await _assetBundle.loadString(
      'assets/demo/products/products_data.json',
    );
    final legacyProducts = List<Map<String, dynamic>>.from(
      jsonDecode(jsonString),
    );
    _productsCache = legacyProducts.map((product) {
      return {
        'productId': product['productId']?.toString() ?? product['id'].toString(),
        'name': product['name'],
        'basePrice': product['basePrice'],
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'isActive': true,
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllProducts({
    bool includeDeactivated = false,
  }) async {
    await _load();
    return _productsCache!
        .where((product) => includeDeactivated || product['isActive'] == true)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getProductById(String id) async {
    await _load();
    return Map<String, dynamic>.from(
      _productsCache!.firstWhere((product) => product['productId'] == id),
    );
  }

  @override
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> json) async {
    await _load();
    final product = {
      ...json,
      'productId': 'demo-${DateTime.now().microsecondsSinceEpoch}',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'isActive': true,
    };
    _productsCache!.insert(0, product);
    return Map<String, dynamic>.from(product);
  }

  @override
  Future<Map<String, dynamic>> patchProduct(
    String id,
    Map<String, dynamic> json,
  ) async {
    await _load();
    final index = _productsCache!.indexWhere(
      (product) => product['productId'] == id,
    );
    if (index == -1) throw Exception('Product not found');
    _productsCache![index] = {..._productsCache![index], ...json};
    return Map<String, dynamic>.from(_productsCache![index]);
  }

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String name) async {
    await _load();
    for (final product in _productsCache!) {
      if ((product['name'] as String).toLowerCase() == name.toLowerCase()) {
        return Map<String, dynamic>.from(product);
      }
    }
    return null;
  }
}
