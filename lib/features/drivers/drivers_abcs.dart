import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';

abstract interface class DriverDataSource {
  Future<List<Map<String, dynamic>>> getAllDrivers({
    bool includeDeactivated = false,
  });
  Future<Map<String, dynamic>> getDriverById(String id);
  Future<Map<String, dynamic>> createDriver(Map<String, dynamic> json);
  Future<Map<String, dynamic>> patchDriver(
    String id,
    Map<String, dynamic> json,
  );
  Future<void> deactivateDriver(String id);

  Future<Map<String, dynamic>?> checkDuplicate(String name);
}

abstract interface class DriverRepository {
  Future<List<Driver>> getAvailableDrivers({bool includeDeactivated = false});
  Future<Driver> getDriverById(String id);

  Future<Driver> createDriver(CreateDriverRequest request);

  Future<Driver> updateDriver(String id, UpdateDriverRequest request);
  Future<void> deactivateDriver(String id);

  Future<Driver?> checkDuplicate(String name);
}
