import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/delivery_route.dart';
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
    // ДЕМО-ХАК: Считаем агрегированные данные для DeliveryDay на основе ВСЕХ маршрутов за эту дату
    // =========================================================================
    try {
      final String sheetDateStr = sheetJson['date'] ??
          DateTime.now().toIso8601String();
      final DateTime sheetDate = DateTime.parse(sheetDateStr);

      // 1. Получаем абсолютно все маршруты из кэша (включая только что добавленный)
      final allRoutes = _routesCache ?? [];

      int totalClientsCount = 0;
      int bottlesCount = 0;
      int returnsCount = 0;
      int glassesCount = 0;
      int waterCoolerCount = 0;
      int coolerRepairCount = 0;
      double totalAmount = 0.0;

      // 2. Бежим по всем маршрутам и собираем статистику ТОЛЬКО за эту дату
      for (var route in allRoutes) {
        final routeDateStr = route['date'] ?? '';
        if (routeDateStr.isEmpty) continue;

        final DateTime routeDate = DateTime.parse(routeDateStr);

        // Сравниваем только день, месяц и год
        if (routeDate.year == sheetDate.year &&
            routeDate.month == sheetDate.month &&
            routeDate.day == sheetDate.day) {
          final List<dynamic> points = route['points'] ?? [];
          totalClientsCount +=
              points.length; // Плюсуем точки всех машин за день

          for (var point in points) {
            final List<dynamic> items = point['items'] ?? [];
            for (var item in items) {
              final String name = (item['productName'] ?? '')
                  .toString()
                  .toLowerCase();
              final int quantity = int.tryParse(item['quantity'].toString()) ??
                  0;
              final double price = double.tryParse(item['price'].toString()) ??
                  0.0;

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

      // 3. Формируем единую карту для дня доставки
      final Map<String, dynamic> generatedDayJson = {
        'date': sheetDateStr,
        'clientsCount': totalClientsCount,
        'bottlesCount': bottlesCount,
        'returnsCount': returnsCount,
        'glassesCount': glassesCount,
        'waterCoolerCount': waterCoolerCount,
        'coolerRepairCount': coolerRepairCount,
        'totalAmount': totalAmount,
      };

      // 4. Передаем данные в дата-сорс дней доставки для умного сохранения/обновления
      await _deliveryDayDataSource.updateOrCreateDeliveryDay(generatedDayJson);
    } catch (e) {
      print('Ошибка работы демо-хака генерации дня доставки: $e');
    }
    // =========================================================================


    return finalSheet;
  }
}
