import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/cars_abcs.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';

class CarRepositoryImpl implements CarRepository {
  final CarDataSource dataSource;
  CarRepositoryImpl(this.dataSource);

  @override
  Future<List<Car>> getAvailableCars({bool includeDeactivated = false}) async {
    final list = await dataSource.getAllCars(
      includeDeactivated: includeDeactivated,
    );
    return list.map(Car.fromJson).toList();
  }

  @override
  Future<Car> getCarById(String id) async {
    final json = await dataSource.getCarById(id);
    return Car.fromJson(json);
  }

  @override
  Future<Car> createCar(CreateCarRequest car) async {
    final request = car.toJson()..['number'] = canonicalCarNumber(car.number);
    final json = await dataSource.createCar(request);
    return Car.fromJson(json);
  }

  @override
  Future<Car> updateCar(String id, UpdateCarRequest request) async {
    final payload = request.toJson();
    if (request.number != null) {
      payload['number'] = canonicalCarNumber(request.number!);
    }
    final json = await dataSource.patchCar(id, payload);
    return Car.fromJson(json);
  }

  @override
  Future<Car> deactivateCar(String id) async {
    final json = await dataSource.patchCar(id, {'isActive': false});
    return Car.fromJson(json);
  }

  @override
  Future<Car?> checkDuplicate(String number) async {
    final json = await dataSource.checkDuplicate(canonicalCarNumber(number));
    if (json == null) return null;
    return Car.fromJson(json);
  }
}
