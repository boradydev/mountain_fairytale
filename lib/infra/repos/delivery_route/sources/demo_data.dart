import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/sources/demo_data.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/delivery_route.dart';

class DemoDeliveryRouteDataSource implements DeliveryRouteDataSource {
  final AssetBundle _assetBundle;
  final DemoDeliveryDataSource _deliveryDayDataSource;
  List<Map<String, dynamic>>? _routesCache;

  DemoDeliveryRouteDataSource({
    AssetBundle? assetBundle,
    required this._deliveryDayDataSource,
  }) : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getAllRouteSheets() async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (_routesCache != null) return _routesCache!;

    final jsonString = await _assetBundle.loadString(
      'assets/demo/delivery_routes/routes_data.json',
    );
    _routesCache = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    return _routesCache!;
  }

  @override
  Future<Map<String, dynamic>> getRouteSheetById(int id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (_routesCache == null) await getAllRouteSheets();
    return _routesCache!.firstWhere(
      (e) => int.parse(e['id'].toString()) == id,
      orElse: () => throw Exception('Route sheet not found'),
    );
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
    await _recalculateDeliveryDayHack(finalSheet['date']);

    return finalSheet;
  }

  @override
  Future<Map<String, dynamic>> patchRouteSheet(
    int id,
    Map<String, dynamic> json,
  ) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (_routesCache == null) await getAllRouteSheets();

    final index = _routesCache!.indexWhere(
      (e) => int.parse(e['id'].toString()) == id,
    );
    if (index == -1) throw Exception('Route sheet not found');

    final updated = Map<String, dynamic>.from(_routesCache![index]);
    json.forEach((key, value) {
      if (value != null) updated[key] = value;
    });

    _routesCache![index] = updated;
    await _recalculateDeliveryDayHack(updated['date']);

    return updated;
  }

  @override
  Future<void> deleteRouteSheet(int id) async {
    await Future.delayed(const Duration(milliseconds: 40));
    if (_routesCache == null) await getAllRouteSheets();

    final index = _routesCache!.indexWhere(
      (e) => int.parse(e['id'].toString()) == id,
    );
    if (index != -1) {
      final targetDate = _routesCache![index]['date'];
      _routesCache!.removeAt(index);
      await _recalculateDeliveryDayHack(targetDate);
    }
  }

  Future<void> _recalculateDeliveryDayHack(String? dateStr) async {
    if (dateStr == null || dateStr.isEmpty) return;
    try {
      final DateTime sheetDate = DateTime.parse(dateStr);
      final allRoutes = _routesCache ?? [];

      int totalClientsCount = 0;
      int bottlesCount = 0;
      int returnsCount = 0;
      int glassesCount = 0;
      int waterCoolerCount = 0;
      int coolerRepairCount = 0;
      double totalAmount = 0.0;

      for (var route in allRoutes) {
        final routeDateStr = route['date'] ?? '';
        if (routeDateStr.isEmpty) continue;

        final DateTime routeDate = DateTime.parse(routeDateStr);
        if (routeDate.year == sheetDate.year &&
            routeDate.month == sheetDate.month &&
            routeDate.day == sheetDate.day) {
          final List<dynamic> points = route['points'] ?? [];
          totalClientsCount += points.length;

          for (var point in points) {
            final List<dynamic> items = point['items'] ?? [];
            for (var item in items) {
              final String name = (item['productName'] ?? '')
                  .toString()
                  .toLowerCase();
              final int quantity =
                  int.tryParse(item['quantity'].toString()) ?? 0;
              final double price =
                  double.tryParse(item['price'].toString()) ?? 0.0;

              totalAmount += quantity * price;

              if (name.contains('вода') || name.contains('19л')) {
                bottlesCount += quantity;
              } else if (name.contains('возврат')) {
                returnsCount += quantity;
              } else if (name.contains('стакан')) {
                glassesCount += quantity;
              } else if (name.contains('кулер') && !name.contains('ремонт')) {
                waterCoolerCount += quantity;
              } else if (name.contains('ремонт')) {
                coolerRepairCount += quantity;
              }
            }
          }
        }
      }

      final Map<String, dynamic> generatedDayJson = {
        'date': dateStr,
        'clientsCount': totalClientsCount,
        'bottlesCount': bottlesCount,
        'returnsCount': returnsCount,
        'glassesCount': glassesCount,
        'waterCoolerCount': waterCoolerCount,
        'coolerRepairCount': coolerRepairCount,
        'totalAmount': totalAmount,
      };

      await _deliveryDayDataSource.updateOrCreateDeliveryDay(generatedDayJson);
    } catch (e) {
      print('Ошибка работы демо-хака: $e');
    }
  }
}
