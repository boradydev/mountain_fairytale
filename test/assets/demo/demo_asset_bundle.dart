import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class DemoAssetBundle extends CachingAssetBundle {
  // Закрытый конструктор
  DemoAssetBundle._();

  // Единственный экземпляр на все тесты (Singleton)
  static final DemoAssetBundle instance = DemoAssetBundle._();

  @override
  Future<ByteData> load(String key) async {
    // key — это путь к файлу, который запрашивает код (например, 'assets/demo/delivery_days/cards_data.json')
    final file = File(key);

    if (!await file.exists()) {
      throw FlutterError('Тестовый ассет не найден по пути: $key');
    }

    final bytes = await file.readAsBytes();
    return ByteData.view(bytes.buffer);
  }
}
