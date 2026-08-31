import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/delivery_day/demo_data_source.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_day/repo.dart';

import '../../../assets/demo/demo_asset_bundle.dart';
import 'print_model.dart';

void main() {
  final demoBundle = DemoAssetBundle.instance;

  test('should load delivery days from repository', () async {
    final dataSource = DemoDeliveryDataSource(assetBundle: demoBundle);
    final repository = ApiDeliveryRepository(dataSource);

    final deliveryDays = await repository.getDeliveryDays();

    expect(deliveryDays, isNotEmpty);
    expect(deliveryDays.length, 100);

    print('\n--- СПИСОК ВСЕХ ДНЕЙ ДОСТАВКИ ---');
    for (final day in deliveryDays) {
      // Передаем карту json, функция сама соберет все поля динамически
      printModel(day.toJson(), title: 'ДЕНЬ ДОСТАВКИ ID: ${day.id}');
    }
  });

  test('should load single delivery day by id from repository', () async {
    final dataSource = DemoDeliveryDataSource(assetBundle: demoBundle);
    final repository = ApiDeliveryRepository(dataSource);
    const targetId = 1;

    final deliveryDay = await repository.getDeliveryDay(targetId);

    expect(deliveryDay.id, targetId);
    expect(deliveryDay.clientsCount, 10);

    print('\n');
    // Вывод одной модели
    printModel(deliveryDay.toJson(), title: 'НАЙДЕННЫЙ ДЕНЬ ПО ID: $targetId');
  });
}
