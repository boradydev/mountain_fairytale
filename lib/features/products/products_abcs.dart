import 'package:mountain_fairytale/features/products/data/product_model.dart';

abstract interface class ProductDataSource {
  Future<List<Map<String, dynamic>>> getAllProducts({
    bool includeDeactivated = false,
  });

  Future<Map<String, dynamic>> getProductById(String id);

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> json);

  Future<Map<String, dynamic>> patchProduct(
    String id,
    Map<String, dynamic> json,
  );

  Future<Map<String, dynamic>?> checkDuplicate(String name);
}

abstract interface class ProductRepository {
  Future<List<Product>> getAvailableProducts({bool includeDeactivated = false});

  Future<Product> getProductById(String id);

  Future<Product> createProduct(CreateProductRequest request);

  Future<Product> updateProduct(String id, UpdateProductRequest request);

  Future<Product?> checkDuplicate(String name);
}
