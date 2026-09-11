import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/car_contracts.dart';

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
  Future<Car> createCar(CreateCarRequest car) async {
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

  @override
  Future<Car?> checkDuplicate(String number) async {
    final json = await dataSource.checkDuplicate(number);
    if (json == null) return null;
    return Car.fromJson(json);
  }
}
