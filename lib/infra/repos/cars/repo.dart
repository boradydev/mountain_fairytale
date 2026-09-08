import 'package:mountain_fairytale/infra/repos/abcs.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repo.dart';
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
  Future<Car> createCar(Car car) async {
    final json = await dataSource.createCar(car.toJson());
    return Car.fromJson(json);
  }
}
