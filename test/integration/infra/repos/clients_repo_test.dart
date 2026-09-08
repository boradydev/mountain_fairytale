import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infra/repos/clients/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/clients/repo.dart';

import '../../../assets/demo/demo_asset_bundle.dart';
import 'print_model.dart';

void main() {
  final demoBundle = DemoAssetBundle.instance;

  test('should load clients from repository', () async {
    final dataSource = DemoClientDataSource(assetBundle: demoBundle);
    final repository = ClientRepositoryImpl(dataSource);

    final clients = await repository.getAllClients();

    expect(clients, isNotEmpty);

    print('\n--- СПИСОК ВСЕХ КЛИЕНТОВ ---');
    for (final client in clients) {
      // Передаем карту json, функция сама соберет все поля динамически
      printModel(client.toJson(), title: 'КЛИЕНТ ID: ${client.id}');
    }
  });

  test('should update cooldown for a client', () async {
    final dataSource = DemoClientDataSource(assetBundle: demoBundle);
    final repository = ClientRepositoryImpl(dataSource);
    const clientId = 1;
    final newCooldownUntil = DateTime.now().add(Duration(days: 7));

    final updatedClient = await repository.updateCooldown(clientId, newCooldownUntil);

    expect(updatedClient.id, clientId);
    expect(updatedClient.cooldownUntil, newCooldownUntil);

    print('\n');
    // Вывод одной модели
    printModel(updatedClient.toJson(), title: 'ОБНОВЛЕННЫЙ КЛИЕНТ ID: $clientId');
  });

  test('should check for duplicate client', () async {
    final dataSource = DemoClientDataSource(assetBundle: demoBundle);
    final repository = ClientRepositoryImpl(dataSource);
    const name = 'Test Client';
    const address = 'Test Address';

    final duplicateClient = await repository.checkDuplicate(name, address);

    if (duplicateClient != null) {
      print('\n');
      // Вывод одной модели
      printModel(duplicateClient.toJson(), title: 'ДУБЛИКАТ КЛИЕНТА');
    } else {
      print('\n--- НЕ НАЙДЕНО ДУБЛИКАТОВ ---');
    }
  });

  test('should create a new client', () async {
    final dataSource = DemoClientDataSource(assetBundle: demoBundle);
    final repository = ClientRepositoryImpl(dataSource);
    const name = 'New Client';
    const phone = '1234567890';
    const address = 'New Address';
    const thresholdDays = 5;

    final newClient = await repository.createClient(
      name: name,
      phone: phone,
      address: address,
      thresholdDays: thresholdDays,
    );

    expect(newClient.name, name);
    expect(newClient.phone, phone);
    expect(newClient.address, address);
    expect(newClient.sleepingThresholdDays, thresholdDays);

    print('\n');
    // Вывод одной модели
    printModel(newClient.toJson(), title: 'НОВЫЙ КЛИЕНТ');
  });
}
