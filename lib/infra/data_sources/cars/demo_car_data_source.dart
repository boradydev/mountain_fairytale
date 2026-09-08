import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/data_sources/abcs.dart';

class DemoCarDataSource implements CarDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _carsCache;

  DemoCarDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllCars() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_carsCache != null) return _carsCache!;

    final jsonString = await _assetBundle.loadString(
      'assets/demo/cars/cars_data.json',
    );
    _carsCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _carsCache!;
  }

  @override
  Future<Map<String, dynamic>> createCar(Map<String, dynamic> carJson) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_carsCache == null) await getAllCars();

    final newId = _carsCache!.isEmpty
        ? 1
        : _carsCache!
                  .map((item) => int.parse(item['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final newCar = {...carJson, 'id': newId};
    _carsCache!.insert(0, newCar);
    return newCar;
  }
}
