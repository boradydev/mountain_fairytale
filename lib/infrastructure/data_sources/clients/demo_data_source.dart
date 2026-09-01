import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';

class DemoClientDataSource implements ClientDataSource {
  final AssetBundle _assetBundle;
  List<Map<String, dynamic>>? _cache;

  static const _clientsPath = 'assets/demo/clients/clients_card_data.json';

  // Конструктор принимает бандл, по умолчанию инициализируется системным rootBundle
  DemoClientDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  Future<List<Map<String, dynamic>>> _getDemoJson() async {
    if (_cache != null) {
      return _cache!;
    }

    final jsonString = await _assetBundle.loadString(_clientsPath);

    final jsonData = List<Map<String, dynamic>>.from(jsonDecode(jsonString));

    _cache = jsonData;

    return jsonData;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllClients() async {
    // Эмулируем задержку сети.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    return _getDemoJson();
  }
}
