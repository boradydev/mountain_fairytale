import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductDataSource dataSource;

  ProductRepositoryImpl(this.dataSource);

  @override
  Future<List<Product>> getAvailableProducts({
    bool includeDeactivated = false,
  }) async {
    final list = await dataSource.getAllProducts(
      includeDeactivated: includeDeactivated,
    );
    return list.map(Product.fromJson).toList();
  }

  @override
  Future<Product> getProductById(String id) async =>
      Product.fromJson(await dataSource.getProductById(id));

  @override
  Future<Product> createProduct(CreateProductRequest request) async =>
      Product.fromJson(await dataSource.createProduct(request.toJson()));

  @override
  Future<Product> updateProduct(
    String id,
    UpdateProductRequest request,
  ) async =>
      Product.fromJson(await dataSource.patchProduct(id, request.toJson()));

  @override
  Future<Product?> checkDuplicate(String name) async {
    final json = await dataSource.checkDuplicate(name);
    return json == null ? null : Product.fromJson(json);
  }
}
