import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/features/drivers/drivers_abcs.dart';

class DemoDriverDataSource implements DriverDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _driversCache;

  DemoDriverDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllDrivers({
    bool includeDeactivated = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 40));
    if (_driversCache != null) {
      return _driversCache!
          .where((d) => includeDeactivated || d['isActive'] == true)
          .toList();
    }
    final jsonString = await _assetBundle.loadString(
      'assets/demo/driver/drivers_data.json',
    );
    _driversCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _driversCache!
        .where((d) => includeDeactivated || d['isActive'] == true)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getDriverById(String id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (_driversCache == null) await getAllDrivers();
    return _driversCache!.firstWhere(
      (e) => e['driverId'] == id,
      orElse: () => throw Exception('Driver not found'),
    );
  }

  @override
  Future<Map<String, dynamic>> createDriver(
    Map<String, dynamic> driverJson,
  ) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (_driversCache == null) await getAllDrivers();
    final newDriver = {
      ...driverJson,
      'driverId':
          '00000000-0000-4000-8000-${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}',
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': true,
    };
    _driversCache!.insert(0, newDriver);
    return newDriver;
  }

  @override
  Future<Map<String, dynamic>> patchDriver(
    String id,
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (_driversCache == null) await getAllDrivers();
    final index = _driversCache!.indexWhere((e) => e['driverId'] == id);
    if (index == -1) throw Exception('Driver not found');
    final updated = Map<String, dynamic>.from(_driversCache![index]);
    json.forEach((key, value) {
      if (value != null) updated[key] = value;
    });
    _driversCache![index] = updated;
    return updated;
  }

  @override
  Future<void> deactivateDriver(String id) async {
    await Future.delayed(const Duration(milliseconds: 40));
    if (_driversCache == null) await getAllDrivers();
    await patchDriver(id, {'isActive': false});
  }

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (_driversCache == null) await getAllDrivers();

    final cleanName = name.trim().toLowerCase();
    if (cleanName.isEmpty) return null;

    try {
      final duplicate = _driversCache!.firstWhere(
        (driver) => driver['name'].toString().toLowerCase() == cleanName,
      );
      return duplicate;
    } catch (_) {
      return null;
    }
  }
}
