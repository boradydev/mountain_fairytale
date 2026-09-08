import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/abcs.dart';

class DemoDeliveryDataSource implements DeliveryDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _cache;

  static const _deliveryDaysPath = 'assets/demo/delivery_days/delivery_days_card_data.json';

  // Конструктор принимает бандл, по умолчанию инициализируется системным rootBundle
  DemoDeliveryDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  Future<List<Map<String, dynamic>>> _getDemoJson() async {
    if (_cache != null) {
      return _cache!;
    }

    final jsonString = await _assetBundle.loadString(
      _deliveryDaysPath,
    );

    final jsonData = List<Map<String, dynamic>>.from(
      jsonDecode(jsonString),
    );

    _cache = jsonData;

    return jsonData;
  }

  @override
  Future<List<Map<String, dynamic>>> getDeliveryDays({
    required int offset,
    required int limit,
  }) async {
    // Эмулируем задержку сети.
    await Future<void>.delayed(
      const Duration(milliseconds: 600),
    );

    final jsonData = await _getDemoJson();

    return jsonData.skip(offset).take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>> getDeliveryDay(int id) async {
    // Эмулируем задержку сети.
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    final deliveryDays = await _getDemoJson();

    return deliveryDays.firstWhere((deliveryDay) => deliveryDay['id'] == id);
  }


  /// ДЕМО-ХАК: Метод для ручного добавления сгенерированного дня доставки в кэш
  Future<void> addDeliveryDay(Map<String, dynamic> dayJson) async {
    if (_cache == null) {
      await _getDemoJson();
    }

    // Вычисляем новый ID для дня доставки
    final int newId = _cache!.isEmpty
        ? 1
        : _cache!.map((d) => int.parse(d['id'].toString())).reduce((a, b) =>
    a > b ? a : b) + 1;

    final finalDay = {...dayJson, 'id': newId};

    // Вставляем в начало, чтобы новый день сразу появился на дашборде сверху
    _cache!.insert(0, finalDay);
  }
}
