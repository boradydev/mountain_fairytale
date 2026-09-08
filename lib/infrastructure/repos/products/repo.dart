import 'package:mountain_fairytale/infrastructure/data_sources/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/products/abcs.dart';
import 'package:mountain_fairytale/infrastructure/repos/products/models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductDataSource dataSource;

  ProductRepositoryImpl(this.dataSource);

  @override
  Future<List<Product>> getAvailableProducts() async {
    final list = await dataSource.getAllProducts();
    return list.map(Product.fromJson).toList();
  }
}
