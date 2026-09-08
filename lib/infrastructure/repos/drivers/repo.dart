import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/drivers/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/drivers/models/driver_model.dart';

class DriverRepositoryImpl implements DriverRepository {
  final DriverDataSource dataSource;

  DriverRepositoryImpl(this.dataSource);

  @override
  Future<List<Driver>> getAvailableDrivers() async {
    final list = await dataSource.getAllDrivers();
    return list.map(Driver.fromJson).toList();
  }

  @override
  Future<Driver> createDriver(Driver driver) async {
    // Репозиторий принимает модель, переводит в JSON map
    final json = await dataSource.createDriver(driver.toJson());
    // Возвращает готовую модель обратно на UI
    return Driver.fromJson(json);
  }
}
