import 'package:mountain_fairytale/core/repos/car_contracts.dart';
import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';

class CarRepositoryImpl implements CarRepository {
  final CarDataSource dataSource;
  CarRepositoryImpl(this.dataSource);

  @override
  Future<List<Car>> getAvailableCars() async {
    final list = await dataSource.getAllCars();
    return list.map(Car.fromJson).toList();
  }

  @override
  Future<Car> getCarById(int id) async {
    final json = await dataSource.getCarById(id);
    return Car.fromJson(json);
  }

  @override
  Future<Car> createCar(Car car) async {
    final json = await dataSource.createCar(car.toJson());
    return Car.fromJson(json);
  }

  @override
  Future<Car> updateCar(int id, UpdateCarRequest request) async {
    final json = await dataSource.patchCar(id, request.toJson());
    return Car.fromJson(json);
  }

  @override
  Future<void> deleteCar(int id) async {
    await dataSource.deleteCar(id);
  }
}
