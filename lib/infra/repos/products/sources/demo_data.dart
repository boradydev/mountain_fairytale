import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/abcs.dart';

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
      'assets/demo/products/products_data.json',
    );
    _productsCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _productsCache!;
  }
}
