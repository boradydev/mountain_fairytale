// Интерфейс для дней доставки (Дашборд)
abstract interface class DeliveryDataSource {
  Future<List<Map<String, dynamic>>> getDeliveryDays({
    required int offset,
    required int limit,
  });
  Future<Map<String, dynamic>> getDeliveryDay(int id);
}

// Интерфейс для клиентов
abstract interface class ClientDataSource {
  Future<List<Map<String, dynamic>>> getAllClients();

  Future<Map<String, dynamic>> updateCooldown(int clientId,
      String cooldownUntilIso);
  Future<Map<String, dynamic>?> checkDuplicate(String name, String address);
  Future<Map<String, dynamic>> createClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
  });
}

// Интерфейс для водителей
abstract interface class DriverDataSource {
  Future<List<Map<String, dynamic>>> getAllDrivers();

  Future<Map<String, dynamic>> createDriver(Map<String, dynamic> driverJson);
}

// Интерфейс для автомобилей
abstract interface class CarDataSource {
  Future<List<Map<String, dynamic>>> getAllCars();

  Future<Map<String, dynamic>> createCar(Map<String, dynamic> carJson);
}

// Интерфейс для продуктов/услуг
abstract interface class ProductDataSource {
  Future<List<Map<String, dynamic>>> getAllProducts();
}

// Интерфейс для маршрутных листов конструктора
abstract interface class DeliveryRouteDataSource {
  Future<List<Map<String, dynamic>>> getAllRouteSheets();
  Future<Map<String, dynamic>> createRouteSheet(Map<String, dynamic> sheetJson);
}
