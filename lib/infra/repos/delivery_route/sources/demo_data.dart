import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/abcs.dart';

class DemoDeliveryRouteDataSource implements DeliveryRouteDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _routesCache;

  DemoDeliveryRouteDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllRouteSheets() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_routesCache != null) return _routesCache!;

    final jsonString = await _assetBundle.loadString(
      'assets/demo/delivery_routes/routes_data.json',
    );
    _routesCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _routesCache!;
  }

  @override
  Future<Map<String, dynamic>> createRouteSheet(
    Map<String, dynamic> sheetJson,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_routesCache == null) await getAllRouteSheets();

    final int newId = _routesCache!.isEmpty
        ? 1
        : _routesCache!
                  .map((r) => int.parse(r['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final Map<String, dynamic> finalSheet = Map<String, dynamic>.from(
      sheetJson,
    );
    finalSheet['id'] = newId;

    _routesCache!.insert(0, finalSheet);
    return finalSheet;
  }
}
