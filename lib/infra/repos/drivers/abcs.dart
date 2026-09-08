import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';

abstract interface class DriverRepository {
  Future<List<Driver>> getAvailableDrivers();

  Future<Driver> createDriver(Driver driver);
}
