import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getAvailableProducts();
}
