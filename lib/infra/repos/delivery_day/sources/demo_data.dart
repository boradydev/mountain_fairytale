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


  /// ДЕМО-ХАК: Умное добавление или обновление существующего дня доставки в кэше
  Future<void> updateOrCreateDeliveryDay(Map<String, dynamic> dayJson) async {
    if (_cache == null) {
      await _getDemoJson();
    }

    final String targetDateStr = dayJson['date'] ?? '';
    if (targetDateStr.isEmpty) return;

    final DateTime targetDate = DateTime.parse(targetDateStr);

    // Ищем, есть ли уже день с такой датой в кэше
    final existingIndex = _cache!.indexWhere((day) {
      final String dayDateStr = day['date'] ?? '';
      if (dayDateStr.isEmpty) return false;
      final DateTime dayDate = DateTime.parse(dayDateStr);
      return dayDate.year == targetDate.year &&
          dayDate.month == targetDate.month &&
          dayDate.day == targetDate.day;
    });

    if (existingIndex != -1) {
      // ДЕНЬ НАЙДЕН: Обновляем статистику, сохраняя старый ID
      final int existingId = int.parse(_cache![existingIndex]['id'].toString());
      _cache![existingIndex] = {
        ...dayJson,
        'id': existingId, // ID не должен меняться при обновлении данных
      };
    } else {
      // ДЕНЬ НЕ НАЙДЕН: Создаем новую запись
      final int newId = _cache!.isEmpty
          ? 1
          : _cache!.map((d) => int.parse(d['id'].toString())).reduce((a,
          b) => a > b ? a : b) + 1;

      final finalDay = {
        ...dayJson,
        'id': newId,
      };

      // Вставляем в начало списка
      _cache!.insert(0, finalDay);
    }
  }

}
