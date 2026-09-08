import 'package:mountain_fairytale/infrastructure/repos/products/models/product_model.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getAvailableProducts();
}
