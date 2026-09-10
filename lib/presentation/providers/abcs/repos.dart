import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_day/models/delivery_day_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/models/payment_method_model.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';


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


abstract interface class PaymentMethodDataSource {
  Future<List<Map<String, dynamic>>> getAllPaymentMethods();

  Future<Map<String, dynamic>> getPaymentMethodById(int id);

  Future<Map<String, dynamic>> createPaymentMethod(Map<String, dynamic> json);

  Future<Map<String, dynamic>> patchPaymentMethod(int id,
      Map<String, dynamic> json);

  Future<void> deletePaymentMethod(int id);
}

abstract interface class PaymentMethodRepository {
  Future<List<PaymentMethod>> getAllPaymentMethods();

  Future<PaymentMethod> getPaymentMethodById(int id);

  Future<PaymentMethod> createPaymentMethod(
      CreatePaymentMethodRequest request);
  Future<PaymentMethod> updatePaymentMethod(int id,
      UpdatePaymentMethodRequest request);
  Future<void> deletePaymentMethod(int id);
}

abstract interface class SalesRepresentativeDataSource {
  Future<List<Map<String, dynamic>>> getAllSalesRepresentatives();

  Future<Map<String, dynamic>> getSalesRepresentativeById(int id);

  Future<Map<String, dynamic>> createSalesRepresentative(
      Map<String, dynamic> json);

  Future<Map<String, dynamic>> patchSalesRepresentative(int id,
      Map<String, dynamic> json);

  Future<void> deleteSalesRepresentative(int id);
}

abstract interface class SalesRepresentativeRepository {
  Future<List<SalesRepresentative>> getAllSalesRepresentatives();

  Future<SalesRepresentative> getSalesRepresentativeById(int id);

  Future<SalesRepresentative> createSalesRepresentative(
      CreateSalesRepresentativeRequest request);
  Future<SalesRepresentative> updateSalesRepresentative(int id,
      UpdateSalesRepresentativeRequest request);
  Future<void> deleteSalesRepresentative(int id);
}
