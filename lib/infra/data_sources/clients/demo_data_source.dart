import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/data_sources/abcs.dart';

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

  @override
  Future<Map<String, dynamic>?> checkDuplicate(String name,
      String address) async {
    await Future<void>.delayed(
        const Duration(milliseconds: 300)); // Имитируем сеть

    if (_cache == null) {
      await _getDemoJson();
    }

    final cleanName = name.trim().toLowerCase();
    final cleanAddress = address.trim().toLowerCase();

    if (cleanName.isEmpty || cleanAddress.isEmpty) return null;

    // Ищем точное совпадение по имени и адресу в кэше
    try {
      final duplicate = _cache!.firstWhere(
            (client) =>
        client['name'].toString().toLowerCase() == cleanName &&
            client['address'].toString().toLowerCase() == cleanAddress,
      );
      return duplicate;
    } catch (_) {
      return null; // Дубликат не найден
    }
  }

  // Реализуем метод добавления внутри дата-сорса:
  @override
  Future<Map<String, dynamic>> createClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
  }) async {
    // Имитируем задержку сети
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Гарантируем, что кэш загружен
    if (_cache == null) {
      await _getDemoJson();
    }

    // Находим максимальный ID в текущем кэше и прибавляем 1
    final int newId = _cache!.isEmpty
        ? 1
        : _cache!.map((c) => int.parse(c['id'].toString())).reduce((a, b) =>
    a > b ? a : b) + 1;

    // Формируем структуру в точном соответствии с JSON-моделью
    final newClientJson = {
      'id': newId,
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'sleepingThresholdDays': thresholdDays,
      'lastDeliveryDate': null,
      'lastDeliveryQuantity': null,
      'cooldownUntil': null,
    };

    // Пушим в начало нашего кэша, чтобы новый клиент сразу отображался сверху
    _cache!.insert(0, newClientJson);

    return newClientJson;
  }

}
