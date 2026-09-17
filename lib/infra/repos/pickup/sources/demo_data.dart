import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/pickup.dart';

class DemoPickupDataSource implements PickupDataSource {
  final AssetBundle _assetBundle;

  List<Map<String, dynamic>>? _pickupCache;

  DemoPickupDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const _pickupPath = 'assets/demo/pickup/pickup_sheets_data.json';

  @override
  Future<List<Map<String, dynamic>>> getAllPickupSheets() async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (_pickupCache != null) {
      return _pickupCache!;
    }

    final jsonString = await _assetBundle.loadString(_pickupPath);

    _pickupCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));

    return _pickupCache!;
  }

  @override
  Future<Map<String, dynamic>> getPickupSheetById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (_pickupCache == null) {
      await getAllPickupSheets();
    }

    return _pickupCache!.firstWhere(
      (e) => int.parse(e['id'].toString()) == id,
      orElse: () => throw Exception('Pickup sheet not found'),
    );
  }

  @override
  Future<Map<String, dynamic>> createPickupSheet(
    Map<String, dynamic> sheetJson,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (_pickupCache == null) {
      await getAllPickupSheets();
    }

    final int newId = _pickupCache!.isEmpty
        ? 1
        : _pickupCache!
                  .map((e) => int.parse(e['id'].toString()))
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final newSheet = {...sheetJson, 'id': newId};

    _pickupCache!.insert(0, newSheet);

    return newSheet;
  }

  @override
  Future<Map<String, dynamic>> patchPickupSheet(
    int id,
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (_pickupCache == null) {
      await getAllPickupSheets();
    }

    final index = _pickupCache!.indexWhere(
      (e) => int.parse(e['id'].toString()) == id,
    );

    if (index == -1) {
      throw Exception('Pickup sheet not found');
    }

    final updated = Map<String, dynamic>.from(_pickupCache![index]);

    json.forEach((key, value) {
      if (value != null) {
        updated[key] = value;
      }
    });

    _pickupCache![index] = updated;

    return updated;
  }

  @override
  Future<void> deletePickupSheet(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (_pickupCache == null) {
      await getAllPickupSheets();
    }

    _pickupCache!.removeWhere((e) => int.parse(e['id'].toString()) == id);
  }
}
