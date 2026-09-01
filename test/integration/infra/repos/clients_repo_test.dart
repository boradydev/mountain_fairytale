import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/clients/demo_data_source.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/repo.dart';

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
}
