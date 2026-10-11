import 'package:mountain_fairytale/features/cars/data/cars_model.dart';

abstract interface class CarDataSource {
  Future<List<Map<String, dynamic>>> getAllCars({
    bool includeDeactivated = false,
  });
  Future<Map<String, dynamic>> getCarById(String id);
  Future<Map<String, dynamic>> createCar(Map<String, dynamic> json);
  Future<Map<String, dynamic>> patchCar(String id, Map<String, dynamic> json);

  Future<Map<String, dynamic>?> checkDuplicate(String number);
}

abstract interface class CarRepository {
  Future<List<Car>> getAvailableCars({bool includeDeactivated = false});
  Future<Car> getCarById(String id);
  Future<Car> createCar(CreateCarRequest car);
  Future<Car> updateCar(String id, UpdateCarRequest request);
  Future<Car> deactivateCar(String id);

  Future<Car?> checkDuplicate(String number);
}
