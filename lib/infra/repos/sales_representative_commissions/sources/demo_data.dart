import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative_commission.dart';

class DemoSalesRepresentativeCommissionDataSource
    implements SalesRepresentativeCommissionDataSource {
  final AssetBundle _assetBundle;

  List<Map<String, dynamic>>? _cache;

  static const _dataPath =
      'assets/demo/sales_representative_commissions/'
      'sales_representative_commissions_data.json';

  DemoSalesRepresentativeCommissionDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  Future<List<Map<String, dynamic>>> _getDemoJson() async {
    if (_cache != null) {
      return _cache!;
    }

    final jsonString = await _assetBundle.loadString(_dataPath);

    _cache = List<Map<String, dynamic>>.from(
      (jsonDecode(jsonString) as List).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );

    return _cache!;
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesRepresentativeCommissions({
    required String dateFrom,
    required String dateTo,
  }) async {
    // Имитируем сетевой запрос.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Пока Demo-источник не фильтрует данные по периоду.
    // В реальном API dateFrom/dateTo будут переданы backend.
    return _getDemoJson();
  }
}
