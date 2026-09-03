import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';

class DemoClientDataSource implements ClientDataSource {
  final AssetBundle _assetBundle;

  // Кэш теперь живет здесь. Именно его мы будем мутировать.
  List<Map<String, dynamic>>? _cache;

  static const _clientsPath = 'assets/demo/clients/clients_card_data.json';

  DemoClientDataSource({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  Future<List<Map<String, dynamic>>> _getDemoJson() async {
    if (_cache != null) {
      return _cache!;
    }

    final jsonString = await _assetBundle.loadString(_clientsPath);
    // Декодируем как изменяемый список
    final jsonData = List<Map<String, dynamic>>.from(
      (jsonDecode(jsonString) as List).map((e) => Map<String, dynamic>.from(e)),
    );

    _cache = jsonData;
    return jsonData;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllClients() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return _getDemoJson();
  }

  @override
  Future<Map<String, dynamic>> updateCooldown(int clientId,
      String cooldownUntilIso) async {
    // Имитируем задержку сети
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Гарантируем, что кэш инициализирован
    if (_cache == null) {
      await _getDemoJson();
    }

    // Ищем клиента в нашем локальном JSON-кэше
    final index = _cache!.indexWhere((client) => client['id'] == clientId);
    if (index == -1) {
      throw Exception('Client with ID $clientId not found in demo data source');
    }

    // Обновляем поле прямо в JSON-карте
    _cache![index]['cooldownUntil'] = cooldownUntilIso;

    // Возвращаем обновленную карту клиента
    return _cache![index];
  }
}
