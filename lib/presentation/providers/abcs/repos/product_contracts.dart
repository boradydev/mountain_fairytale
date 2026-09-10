import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';

abstract interface class ProductDataSource {
  Future<List<Map<String, dynamic>>> getAllProducts();

  Future<Map<String, dynamic>> getProductById(int id);

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> json);

  Future<Map<String, dynamic>> patchProduct(int id, Map<String, dynamic> json);

  Future<void> deleteProduct(int id);
}

abstract interface class ProductRepository {
  Future<List<Product>> getAvailableProducts();

  Future<Product> getProductById(int id);

  Future<Product> createProduct(CreateProductRequest request); // Используем DTO
  Future<Product> updateProduct(
    int id,
    UpdateProductRequest request,
  ); // Используем DTO
  Future<void> deleteProduct(int id);
}
