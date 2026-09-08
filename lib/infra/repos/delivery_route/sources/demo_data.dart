import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/abcs.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/sources/demo_data.dart';

class DemoDeliveryRouteDataSource implements DeliveryRouteDataSource {
  final AssetBundle _assetBundle;
  final DemoDeliveryDataSource _deliveryDayDataSource; // Ссылка для демо-хака
  List<Map<String, dynamic>>? _routesCache;

  DemoDeliveryRouteDataSource({
    AssetBundle? assetBundle,
    required DemoDeliveryDataSource deliveryDayDataSource,
  })
      : _assetBundle = assetBundle ?? rootBundle,
        _deliveryDayDataSource = deliveryDayDataSource;

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
      Map<String, dynamic> sheetJson,) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_routesCache == null) await getAllRouteSheets();

    final int newId = _routesCache!.isEmpty
        ? 1
        : _routesCache!
        .map((r) => int.parse(r['id'].toString()))
        .reduce((a, b) => a > b ? a : b) +
        1;

    final Map<String, dynamic> finalSheet = Map<String, dynamic>.from(
        sheetJson);
    finalSheet['id'] = newId;

    _routesCache!.insert(0, finalSheet);

    // =========================================================================
    // ДЕМО-ХАК: Считаем агрегированные данные для DeliveryDay на основе точек
    // =========================================================================
    try {
      final List<dynamic> points = sheetJson['points'] ?? [];

      int bottlesCount = 0;
      int returnsCount = 0;
      int glassesCount = 0;
      int waterCoolerCount = 0;
      int coolerRepairCount = 0;
      double totalAmount = 0.0;

      for (var point in points) {
        final List<dynamic> items = point['items'] ?? [];
        for (var item in items) {
          final String name = (item['productName'] ?? '')
              .toString()
              .toLowerCase();
          final int quantity = int.tryParse(item['quantity'].toString()) ?? 0;
          final double price = double.tryParse(item['price'].toString()) ?? 0.0;

          totalAmount += quantity * price;

          // Распределяем по категориям на основе названий продуктов (хардкод для демо)
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

      // Формируем JSON-карту в формате модели DeliveryDay
      final Map<String, dynamic> generatedDayJson = {
        'date': sheetJson['date'] ?? DateTime.now().toIso8601String(),
        'clientsCount': points.length,
        'bottlesCount': bottlesCount,
        'returnsCount': returnsCount,
        'glassesCount': glassesCount,
        'waterCoolerCount': waterCoolerCount,
        'coolerRepairCount': coolerRepairCount,
        'totalAmount': totalAmount,
      };

      // Передаем сгенерированный день в дата-сорс дней доставки
      await _deliveryDayDataSource.addDeliveryDay(generatedDayJson);
    } catch (e) {
      print('Ошибка работы демо-хака генерации дня доставки: $e');
    }
    // =========================================================================

    return finalSheet;
  }
}
