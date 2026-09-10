import 'package:mountain_fairytale/core/repos/driver_contracts.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';

class DriverRepositoryImpl implements DriverRepository {
  final DriverDataSource dataSource;

  DriverRepositoryImpl(this.dataSource);

  @override
  Future<List<Driver>> getAvailableDrivers() async {
    final list = await dataSource.getAllDrivers();
    return list.map(Driver.fromJson).toList();
  }

  @override
  Future<Driver> getDriverById(int id) async {
    final json = await dataSource.getDriverById(id);
    return Driver.fromJson(json);
  }

  @override
  Future<Driver> createDriver(CreateDriverRequest request) async {
    final json = await dataSource.createDriver(request.toJson());
    return Driver.fromJson(json);
  }

  @override
  Future<Driver> updateDriver(int id, UpdateDriverRequest request) async {
    final json = await dataSource.patchDriver(id, request.toJson());
    return Driver.fromJson(json);
  }

  @override
  Future<void> deleteDriver(int id) async {
    await dataSource.deleteDriver(id);
  }
}
