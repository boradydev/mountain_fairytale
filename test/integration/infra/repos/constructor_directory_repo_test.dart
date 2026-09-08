import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/cars/demo_car_data_source.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/drivers/demo_driver_data_source.dart';
import 'package:mountain_fairytale/infrastructure/data_sources/products/demo_product_data_source.dart';
import 'package:mountain_fairytale/infrastructure/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/cars/repo.dart';
import 'package:mountain_fairytale/infrastructure/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/drivers/repo.dart';
import 'package:mountain_fairytale/infrastructure/repos/products/repo.dart';

import '../../../assets/demo/demo_asset_bundle.dart';
import 'print_model.dart';

void main() {
  final demoBundle = DemoAssetBundle.instance;

  test(
      'should load available cars and products, and manage drivers via split repositories', () async {
    // Инициализируем декомпозированные источники данных и репозитории
    final carDataSource = DemoCarDataSource(assetBundle: demoBundle);
    final carRepository = CarRepositoryImpl(carDataSource);

    final productDataSource = DemoProductDataSource(assetBundle: demoBundle);
    final productRepository = ProductRepositoryImpl(productDataSource);

    final driverDataSource = DemoDriverDataSource();
    final driverRepository = DriverRepositoryImpl(driverDataSource);

    // 1. Тестируем CarRepository
    final cars = await carRepository.getAvailableCars();
    expect(cars, isNotEmpty);

    print('\n--- СПИСОК ДОСТУПНЫХ АВТОМОБИЛЕЙ ---');
    for (final car in cars) {
      printModel(car.toJson(), title: 'АВТОМОБИЛЬ ID: ${car.id}');
    }

    const testCar = Car(id: 0, model: 'Газель Тест', number: 'Х777ХХ 26');
    final createdCar = await carRepository.createCar(testCar);
    expect(createdCar.id, isNot(0));
    printModel(createdCar.toJson(), title: 'СОЗДАННЫЙ АВТОМОБИЛЬ');

    // 2. Тестируем ProductRepository
    final products = await productRepository.getAvailableProducts();
    expect(products, isNotEmpty);

    print('\n--- СПИСОК ДОСТУПНЫХ ТОВАРОВ И УСЛУГ ---');
    for (final product in products) {
      printModel(product.toJson(), title: 'ТОВАР ID: ${product.id}');
    }

    // 3. Тестируем DriverRepository
    final drivers = await driverRepository.getAvailableDrivers();
    expect(drivers, isNotEmpty);

    print('\n--- СПИСОК ДОСТУПНЫХ ВОДИТЕЛЕЙ ---');
    for (final driver in drivers) {
      printModel(driver.toJson(), title: 'ВОДИТЕЛЬ ID: ${driver.id}');
    }

    const testDriver = Driver(id: 0, name: 'Тестовый Водитель Иванович');
    final createdDriver = await driverRepository.createDriver(testDriver);
    expect(createdDriver.id, isNot(0));
    printModel(createdDriver.toJson(), title: 'СОЗДАННЫЙ ВОДИТЕЛЬ');
  });
}
