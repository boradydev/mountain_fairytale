import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/drivers/drivers_abcs.dart';

class DriverRepositoryImpl implements DriverRepository {
  final DriverDataSource dataSource;

  DriverRepositoryImpl(this.dataSource);

  @override
  Future<List<Driver>> getAvailableDrivers({
    bool includeDeactivated = false,
  }) async {
    final list = await dataSource.getAllDrivers(
      includeDeactivated: includeDeactivated,
    );
    return list.map(Driver.fromJson).toList();
  }

  @override
  Future<Driver> getDriverById(String id) async {
    final json = await dataSource.getDriverById(id);
    return Driver.fromJson(json);
  }

  @override
  Future<Driver> createDriver(CreateDriverRequest request) async {
    final json = await dataSource.createDriver(request.toJson());
    return Driver.fromJson(json);
  }

  @override
  Future<Driver> updateDriver(String id, UpdateDriverRequest request) async {
    final json = await dataSource.patchDriver(id, request.toJson());
    return Driver.fromJson(json);
  }

  @override
  Future<void> deactivateDriver(String id) async {
    await dataSource.deactivateDriver(id);
  }

  @override
  Future<Driver?> checkDuplicate(String name) async {
    final json = await dataSource.checkDuplicate(name);
    if (json == null) return null;
    return Driver.fromJson(json);
  }
}
