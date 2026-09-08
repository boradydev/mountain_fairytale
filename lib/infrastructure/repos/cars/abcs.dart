import 'package:mountain_fairytale/infrastructure/repos/cars/models/car_model.dart';

abstract interface class CarRepository {
  Future<List<Car>> getAvailableCars();

  Future<Car> createCar(Car car);
}
