import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';

class DemoDeliveryDataSource implements DeliveryDataSource {
  final AssetBundle _assetBundle;

  static const _deliveryDaysPath = 'assets/demo/delivery_days/cards_data.json';

  // Конструктор принимает бандл, по умолчанию инициализируется системным rootBundle
  DemoDeliveryDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> getDeliveryDays() async {
    // Используем переданный бандл вместо жестко прописанного rootBundle
    final jsonString = await _assetBundle.loadString(_deliveryDaysPath);
    final jsonData = jsonDecode(jsonString);

    return List<Map<String, dynamic>>.from(jsonData);
  }

  @override
  Future<Map<String, dynamic>> getDeliveryDay(int id) async {
    final deliveryDays = await getDeliveryDays();

    return deliveryDays.firstWhere((deliveryDay) => deliveryDay['id'] == id);
  }
}
