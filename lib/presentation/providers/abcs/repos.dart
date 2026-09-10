import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/models/delivery_day_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';

abstract interface class CarRepository {
  Future<List<Car>> getAvailableCars();
  Future<Car> createCar(Car car);
}

abstract interface class ClientRepository {
  Future<List<Client>> getAllClients();
  Future<Client> updateCooldown(int clientId, DateTime cooldownUntil);
  Future<Client?> checkDuplicate(String name, String address);
  Future<Client> createClient({
    required String name,
    required String phone,
    required String address,
    required int thresholdDays,
  });
}

abstract interface class DeliveryDayRepository {
  Future<List<DeliveryDay>> getDeliveryDays({
    required int offset,
    required int limit,
  });
  Future<DeliveryDay> getDeliveryDay(int id);
}

abstract interface class DeliveryRouteRepository {
  Future<List<DeliveryRouteSheet>> getRouteSheets();
  Future<DeliveryRouteSheet> saveRouteSheet(DeliveryRouteSheet sheet);
}

abstract interface class DriverRepository {
  Future<List<Driver>> getAvailableDrivers();
  Future<Driver> createDriver(Driver driver);
}

abstract interface class ProductRepository {
  Future<List<Product>> getAvailableProducts();
}
