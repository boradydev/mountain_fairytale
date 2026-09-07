import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/products/models/product_model.dart';

class ConstructorDirectoryRepository {
  final CarDataSource carDataSource;
  final ProductDataSource productDataSource;

  ConstructorDirectoryRepository({
    required this.carDataSource,
    required this.productDataSource,
  });

  Future<List<Car>> getAvailableCars() async {
    final list = await carDataSource.getAllCars();
    return list.map(Car.fromJson).toList();
  }

  Future<List<Product>> getAvailableProducts() async {
    final list = await productDataSource.getAllProducts();
    return list.map(Product.fromJson).toList();
  }
}
