import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/features/cars/cars_abcs.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';

class DemoCarDataSource implements CarDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _carsCache;

  DemoCarDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllCars({
    bool includeDeactivated = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 40));
    if (_carsCache != null) return _availableCars(includeDeactivated);
    final jsonString = await _assetBundle.loadString(
      'assets/demo/cars/cars_data.json',
    );
    _carsCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _availableCars(includeDeactivated);
  }

  List<Map<String, dynamic>> _availableCars(bool includeDeactivated) =>
      _carsCache!
          .where((car) => includeDeactivated || car['isActive'] != false)
          .map(_asCarResponse)
          .toList();

  Map<String, dynamic> _asCarResponse(Map<String, dynamic> car) => {
    'carId': car['id'].toString(),
    'model': car['model'],
    'number': car['number'],
    'currentMileage': car['currentMileage'],
    'isActive': car['isActive'] ?? true,
  };

  @override
  Future<Map<String, dynamic>> getCarById(String id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (_carsCache == null) await getAllCars();
    final car = _carsCache!.firstWhere(
      (e) => e['id'].toString() == id,
      orElse: () => throw Exception('Car not found'),
    );
    return _asCarResponse(car);
  }

  @override
  Future<Map<String, dynamic>> createCar(Map<String, dynamic> carJson) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (_carsCache == null) await getAllCars();
    final newId = _carsCache!.isEmpty
        ? 1
        : _carsCache!
                  .map((item) => int.parse(item['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final newCar = {...carJson, 'id': newId, 'isActive': true};
    _carsCache!.insert(0, newCar);
    return _asCarResponse(newCar);
  }

  @override
  Future<Map<String, dynamic>> patchCar(
    String id,
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (_carsCache == null) await getAllCars();
    final index = _carsCache!.indexWhere((e) => e['id'].toString() == id);
    if (index == -1) throw Exception('Car not found');
    final updated = Map<String, dynamic>.from(_carsCache![index]);
    json.forEach((key, value) {
      if (value != null) updated[key] = value;
    });
    _carsCache![index] = updated;
    return _asCarResponse(updated);
  }

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String number) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (_carsCache == null) await getAllCars();

    final cleanNumber = canonicalCarNumber(number);
    if (cleanNumber.isEmpty) return null;

    try {
      final duplicate = _carsCache!.firstWhere(
        (car) => canonicalCarNumber(car['number'].toString()) == cleanNumber,
      );
      return _asCarResponse(duplicate);
    } catch (_) {
      return null;
    }
  }
}
