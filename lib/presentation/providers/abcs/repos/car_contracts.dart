import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';

abstract interface class CarDataSource {
  Future<List<Map<String, dynamic>>> getAllCars();
  Future<Map<String, dynamic>> getCarById(int id);
  Future<Map<String, dynamic>> createCar(Map<String, dynamic> json);
  Future<Map<String, dynamic>> patchCar(int id, Map<String, dynamic> json);
  Future<void> deleteCar(int id);

  Future<Map<String, dynamic>?> checkDuplicate(String number);
}

abstract interface class CarRepository {
  Future<List<Car>> getAvailableCars();
  Future<Car> getCarById(int id);
  Future<Car> createCar(CreateCarRequest car);
  Future<Car> updateCar(int id, UpdateCarRequest request);
  Future<void> deleteCar(int id);

  Future<Car?> checkDuplicate(String number);
}
