import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/core/repos/client_contracts.dart';

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
    return _getDemoJson(); // Просто возвращаем весь кэш
  }


  @override
  Future<Map<String, dynamic>> getClientById(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_cache == null) await _getDemoJson();
    return _cache!.firstWhere((e) => e['id'] == id,
        orElse: () => throw Exception('Client not found'));
  }

  @override
  Future<Map<String, dynamic>> patchClient(int id,
      Map<String, dynamic> json) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_cache == null) await _getDemoJson();
    final index = _cache!.indexWhere((e) => e['id'] == id);
    if (index == -1) throw Exception('Client not found');
    final updated = Map<String, dynamic>.from(_cache![index]);
    json.forEach((key, value) {
      if (value != null) updated[key] = value;
    });
    _cache![index] = updated;
    return updated;
  }

  @override
  Future<void> deleteClient(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_cache == null) await _getDemoJson();
    _cache!.removeWhere((e) => e['id'] == id);
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
  Future<Map<String, dynamic>> createClient(
      Map<String, dynamic> clientJson) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (_cache == null) {
      await _getDemoJson();
    }

    final int newId = _cache!.isEmpty
        ? 1
        : _cache!.map((c) => int.parse(c['id'].toString())).reduce((a, b) =>
    a > b ? a : b) + 1;

    // Формируем финальную структуру на основе пришедшего JSON
    final newClientJson = {
      ...clientJson,
      'id': newId,
      'lastDeliveryDate': null,
      'lastDeliveryQuantity': null,
      'cooldownUntil': null,
    };

    _cache!.insert(0, newClientJson);
    return newClientJson;
  }


}
