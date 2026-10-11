import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';

abstract interface class DriverDataSource {
  Future<List<Map<String, dynamic>>> getAllDrivers();
  Future<Map<String, dynamic>> getDriverById(int id);
  Future<Map<String, dynamic>> createDriver(Map<String, dynamic> json);
  Future<Map<String, dynamic>> patchDriver(int id, Map<String, dynamic> json);
  Future<void> deleteDriver(int id);

  Future<Map<String, dynamic>?> checkDuplicate(String name);
}

abstract interface class DriverRepository {
  Future<List<Driver>> getAvailableDrivers();
  Future<Driver> getDriverById(int id);

  Future<Driver> createDriver(CreateDriverRequest request);

  Future<Driver> updateDriver(int id, UpdateDriverRequest request);
  Future<void> deleteDriver(int id);

  Future<Driver?> checkDuplicate(String name);
}
