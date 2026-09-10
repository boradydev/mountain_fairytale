import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/car_contracts.dart';

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
        'assets/demo/cars/cars_data.json');
    _carsCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _carsCache!;
  }

  @override
  Future<Map<String, dynamic>> getCarById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_carsCache == null) await getAllCars();
    return _carsCache!.firstWhere((e) => e['id'] == id,
        orElse: () => throw Exception('Car not found'));
  }

  @override
  Future<Map<String, dynamic>> createCar(Map<String, dynamic> carJson) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_carsCache == null) await getAllCars();
    final newId = _carsCache!.isEmpty ? 1 : _carsCache!.map((item) =>
        int.parse(item['id'].toString())).reduce((a, b) => a > b ? a : b) + 1;
    final newCar = {...carJson, 'id': newId};
    _carsCache!.insert(0, newCar);
    return newCar;
  }

  @override
  Future<Map<String, dynamic>> patchCar(int id,
      Map<String, dynamic> json) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_carsCache == null) await getAllCars();
    final index = _carsCache!.indexWhere((e) => e['id'] == id);
    if (index == -1) throw Exception('Car not found');
    final updated = Map<String, dynamic>.from(_carsCache![index]);
    json.forEach((key, value) {
      if (value != null) updated[key] = value;
    });
    _carsCache![index] = updated;
    return updated;
  }

  @override
  Future<void> deleteCar(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_carsCache == null) await getAllCars();
    _carsCache?.removeWhere((e) => e['id'] == id);
  }
}
