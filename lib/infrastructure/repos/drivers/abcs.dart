import 'package:mountain_fairytale/infrastructure/repos/drivers/models/driver_model.dart';

abstract interface class DriverRepository {
  Future<List<Driver>> getAvailableDrivers();

  Future<Driver> createDriver(Driver driver);
}
