import 'package:mountain_fairytale/presentation/providers/abcs/repos/product_contracts.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductDataSource dataSource;

  ProductRepositoryImpl(this.dataSource);

  @override
  Future<List<Product>> getAvailableProducts() async {
    final list = await dataSource.getAllProducts();
    return list.map(Product.fromJson).toList();
  }

  @override
  Future<Product> getProductById(int id) async {
    final json = await dataSource.getProductById(id);
    return Product.fromJson(json);
  }

  @override
  Future<Product> createProduct(CreateProductRequest request) async {
    final json = await dataSource.createProduct(request.toJson());
    return Product.fromJson(json);
  }

  @override
  Future<Product> updateProduct(int id, UpdateProductRequest request) async {
    final json = await dataSource.patchProduct(id, request.toJson());
    return Product.fromJson(json);
  }

  @override
  Future<void> deleteProduct(int id) async {
    await dataSource.deleteProduct(id);
  }
}
