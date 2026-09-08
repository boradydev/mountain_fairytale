import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/abcs.dart';

class DemoDriverDataSource implements DriverDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _driversCache;

  DemoDriverDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllDrivers() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_driversCache != null) return _driversCache!;

    final jsonString = await _assetBundle.loadString(
      'assets/demo/driver/drivers_data.json',
    );
    _driversCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _driversCache!;
  }

  @override
  Future<Map<String, dynamic>> createDriver(
    Map<String, dynamic> driverJson,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_driversCache == null) await getAllDrivers();

    final newId = _driversCache!.isEmpty
        ? 1
        : _driversCache!
                  .map((item) => int.parse(item['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final newDriver = {...driverJson, 'id': newId};
    _driversCache!.insert(0, newDriver);
    return newDriver;
  }
}
