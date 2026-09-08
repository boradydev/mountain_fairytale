import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';

class DemoConstructorDataSource
    implements
        CarDataSource,
        DriverDataSource,
        ProductDataSource,
        DeliveryRouteDataSource {
  final AssetBundle _assetBundle;

  List<Map<String, dynamic>>? _carsCache;
  List<Map<String, dynamic>>? _productsCache;
  List<Map<String, dynamic>>? _routesCache;
  List<Map<String, dynamic>>? _driversCache;

  DemoConstructorDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  // --- Реализация CarDataSource ---
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

  // --- Реализация ProductDataSource ---
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

  // --- Реализация DeliveryRouteDataSource ---
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

    // Генерируем новый ID
    final int newId = _routesCache!.isEmpty
        ? 1
        : _routesCache!
                  .map((r) => int.parse(r['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;

    // Создаем изменяемую копию и добавляем ID
    final Map<String, dynamic> finalSheet = Map<String, dynamic>.from(
      sheetJson,
    );
    finalSheet['id'] = newId;

    // Сохраняем в начало фейковой "базы данных"
    _routesCache!.insert(0, finalSheet);
    return finalSheet;
  }

  // --- Реализация DriverDataSource ---
  @override
  Future<List<Map<String, dynamic>>> getAllDrivers() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (_driversCache != null) {
      return _driversCache!;
    }

    _driversCache = [
      {
        'id': 1,
        'name': 'Иванов Иван Иванович',
      },
      {
        'id': 2,
        'name': 'Петров Петр Петрович',
      },
      {
        'id': 3,
        'name': 'Сидоров Алексей Владимирович',
      },
    ];

    return _driversCache!;
  }
}
