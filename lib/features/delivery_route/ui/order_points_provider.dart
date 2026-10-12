import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/clients/clients_abcs.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class OrderPointsProvider extends SafeChangeNotifier {
  // 1. Поля БЕЗ подчеркивания и с аннотацией
  @protected
  final ProductRepository productRepo;
  @protected
  final PaymentMethodRepository paymentMethodRepo;
  @protected
  final ClientRepository clientRepo;

  // 2. Идеальный лаконичный конструктор
  OrderPointsProvider({
    required this.productRepo,
    required this.paymentMethodRepo,
    required this.clientRepo,
  });

  List<Product> products = [];
  bool showInactiveProducts = false;
  bool isLoadingProducts = false;
  String? productLoadError;
  int _productLoadVersion = 0;
  String? productErrorMessage;
  List<PaymentMethod> paymentMethods = [];

  bool isLoadingDirectories = false;

  List<RoutePoint> points = [];

  bool showInactivePaymentMethods = false;
  bool isLoadingPaymentMethods = false;
  String? paymentMethodLoadError;
  String? paymentMethodErrorMessage;
  String? paymentMethodNameError;
  int _paymentLoadVersion = 0;
  final Map<String, PaymentMethod> paymentMethodsById = {};

  Future<void> loadPaymentMethods({bool? includeDeactivated}) async {
    final version = ++_paymentLoadVersion;
    isLoadingPaymentMethods = true;
    paymentMethodLoadError = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final include =
          includeDeactivated ??
          prefs.getBool('show_inactive_payment_methods') ??
          false;
      final loaded = await paymentMethodRepo.getAllPaymentMethods(
        includeDeactivated: include,
      );
      if (version != _paymentLoadVersion) return;
      if (includeDeactivated != null) {
        await prefs.setBool('show_inactive_payment_methods', include);
      }
      if (version != _paymentLoadVersion) return;
      showInactivePaymentMethods = include;
      paymentMethods = loaded;
      for (final method in loaded) {
        paymentMethodsById[method.id] = method;
      }
    } catch (_) {
      if (version == _paymentLoadVersion) {
        paymentMethodLoadError =
            'Не удалось загрузить способы оплаты. Повторите попытку.';
      }
    } finally {
      if (version == _paymentLoadVersion) {
        isLoadingPaymentMethods = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleInactivePaymentMethods(bool value) async {
    if (!isLoadingPaymentMethods) {
      await loadPaymentMethods(includeDeactivated: value);
    }
  }

  Future<void> loadSelectedPaymentMethod(String id) async {
    final method = await paymentMethodRepo.getPaymentMethodById(id);
    paymentMethodsById[method.id] = method;
    for (var i = 0; i < points.length; i++) {
      if (points[i].paymentMethodId == method.id) {
        points[i] = _withPaymentMethod(points[i], method);
      }
    }
    notifyListeners();
  }

  void _applyPaymentMethod(PaymentMethod method) {
    // Invalidate an older list request so it cannot undo a successful mutation.
    _paymentLoadVersion++;
    isLoadingPaymentMethods = false;
    paymentMethodsById[method.id] = method;
    paymentMethods = paymentMethods
        .where((row) => row.id != method.id)
        .toList();
    if (method.isActive || showInactivePaymentMethods) {
      paymentMethods.add(method);
    }
    paymentMethods.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.paymentMethodId == method.id) {
        points[i] = _withPaymentMethod(point, method);
      }
    }
    notifyListeners();
  }

  RoutePoint _withPaymentMethod(RoutePoint point, PaymentMethod method) =>
      RoutePoint(
        clientId: point.clientId,
        clientName: point.clientName,
        city: point.city,
        address: point.address,
        phone: point.phone,
        paymentMethodId: method.id,
        paymentMethod: method.name,
        salesRepresentative: point.salesRepresentative,
        items: point.items,
      );

  Future<bool> selectPointPaymentMethod(
    String clientId,
    PaymentMethod method,
    ClientsProvider clientsProvider,
  ) async {
    if (!method.isActive) return false;
    paymentMethodErrorMessage = null;
    paymentMethodNameError = null;
    try {
      final client = await clientRepo.updateClient(
        clientId,
        UpdateClientRequest(defaultPaymentMethodId: method.id),
      );
      clientsProvider.syncUpdatedClient(client);
      paymentMethodsById[method.id] = method;
      final index = points.indexWhere((point) => point.clientId == clientId);
      if (index != -1) {
        points[index] = _withPaymentMethod(points[index], method);
      }
      notifyListeners();
      return true;
    } catch (_) {
      paymentMethodErrorMessage =
          'Не удалось сохранить способ оплаты клиента. Повторите попытку.';
      return false;
    }
  }

  double get grandTotal =>
      points.fold(0.0, (sum, point) => sum + point.totalAmount);

  Future<void> loadOrderDirectories() async {
    isLoadingDirectories = true;
    notifyListeners();

    try {
      await loadProducts();
      await loadPaymentMethods();
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts({bool? includeDeactivated}) async {
    final version = ++_productLoadVersion;
    isLoadingProducts = true;
    productLoadError = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldIncludeDeactivated =
          includeDeactivated ??
          prefs.getBool('show_inactive_products') ??
          false;
      final loadedProducts = await productRepo.getAvailableProducts(
        includeDeactivated: shouldIncludeDeactivated,
      );
      if (version != _productLoadVersion) return;
      if (includeDeactivated != null) {
        await prefs.setBool('show_inactive_products', includeDeactivated);
      }
      showInactiveProducts = shouldIncludeDeactivated;
      products = loadedProducts;
    } catch (_) {
      if (version == _productLoadVersion) {
        productLoadError = 'Не удалось загрузить товары. Повторите попытку.';
      }
    } finally {
      if (version == _productLoadVersion) {
        isLoadingProducts = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleInactiveProducts(bool value) async {
    if (isLoadingProducts) return;
    await loadProducts(includeDeactivated: value);
  }

  void _applyProduct(Product product) {
    products = products.where((item) => item.id != product.id).toList();
    if (product.isActive || showInactiveProducts) products.insert(0, product);
    notifyListeners();
  }

  void includeActiveProduct(Product product) {
    if (product.isActive) _applyProduct(product);
  }

  void addClientPoint(Client client) {
    if (!client.isActive || points.any((p) => p.clientId == client.id)) {
      return;
    }

    points.add(
      RoutePoint(
        clientId: client.id,
        clientName: client.name,
        city: 'г. Ставрополь',
        address: client.address,
        phone: client.phone,
        paymentMethodId: client.defaultPaymentMethodId,
        paymentMethod:
            paymentMethodsById[client.defaultPaymentMethodId]?.name ??
            client.defaultPaymentMethodName,
        salesRepresentative:
            client.salesRepresentativeName ?? 'Нет представителя',
        items: [],
      ),
    );

    notifyListeners();
  }

  void removePoint(int index) {
    points.removeAt(index);
    notifyListeners();
  }

  void reorderPoints(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final point = points.removeAt(oldIndex);
    points.insert(newIndex, point);

    notifyListeners();
  }

  void addTaskToPoint(int pointIndex, Product product, int quantity) {
    if (!product.isActive || quantity <= 0) return;
    final currentPoint = points[pointIndex];

    final updatedItems = List<DeliveryTaskItem>.from(currentPoint.items);

    final existingIndex = updatedItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) {
      final oldItem = updatedItems[existingIndex];

      updatedItems[existingIndex] = DeliveryTaskItem(
        productId: product.id,
        productName: product.name,
        quantity: oldItem.quantity + quantity,
        price: product.basePrice,
      );
    } else {
      updatedItems.add(
        DeliveryTaskItem(
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          price: product.basePrice,
        ),
      );
    }

    points[pointIndex] = RoutePoint(
      clientId: currentPoint.clientId,
      clientName: currentPoint.clientName,
      city: currentPoint.city,
      address: currentPoint.address,
      phone: currentPoint.phone,
      paymentMethodId: currentPoint.paymentMethodId,
      paymentMethod: currentPoint.paymentMethod,
      salesRepresentative: currentPoint.salesRepresentative,
      items: updatedItems,
    );

    notifyListeners();
  }

  void removeTaskFromPoint(int pointIndex, int taskIndex) {
    points[pointIndex].items.removeAt(taskIndex);
    notifyListeners();
  }

  void updateTaskQuantity(
    int pointIndex,
    int taskIndex,
    int quantity,
  ) {
    if (pointIndex < 0 || pointIndex >= points.length) return;
    if (taskIndex < 0 || taskIndex >= points[pointIndex].items.length) return;
    if (quantity <= 0) return;

    final currentPoint = points[pointIndex];
    final items = List<DeliveryTaskItem>.from(currentPoint.items);
    final oldItem = items[taskIndex];

    items[taskIndex] = DeliveryTaskItem(
      productId: oldItem.productId,
      productName: oldItem.productName,
      quantity: quantity,
      price: oldItem.price,
    );

    points[pointIndex] = RoutePoint(
      clientId: currentPoint.clientId,
      clientName: currentPoint.clientName,
      city: currentPoint.city,
      address: currentPoint.address,
      phone: currentPoint.phone,
      paymentMethodId: currentPoint.paymentMethodId,
      paymentMethod: currentPoint.paymentMethod,
      salesRepresentative: currentPoint.salesRepresentative,
      items: items,
    );

    notifyListeners();
  }

  Future<PaymentMethod?> addPaymentMethod(String name) async {
    paymentMethodErrorMessage = null;
    paymentMethodNameError = null;
    try {
      final created = await paymentMethodRepo.createPaymentMethod(
        CreatePaymentMethodRequest(name: name),
      );
      _applyPaymentMethod(created);
      return created;
    } catch (error) {
      paymentMethodErrorMessage = _paymentSaveError(error);
      return null;
    }
  }

  Future<bool> updatePaymentMethod(String id, String name) async {
    paymentMethodErrorMessage = null;
    paymentMethodNameError = null;
    try {
      final updated = await paymentMethodRepo.updatePaymentMethod(
        id,
        UpdatePaymentMethodRequest(name: name),
      );
      _applyPaymentMethod(updated);
      return true;
    } catch (error) {
      paymentMethodErrorMessage = _paymentSaveError(error);
      return false;
    }
  }

  Future<bool> setPaymentMethodActive(String id, bool isActive) async {
    paymentMethodErrorMessage = null;
    paymentMethodNameError = null;
    try {
      final updated = await paymentMethodRepo.updatePaymentMethod(
        id,
        UpdatePaymentMethodRequest(isActive: isActive),
      );
      _applyPaymentMethod(updated);
      return true;
    } catch (error) {
      paymentMethodErrorMessage = _paymentSaveError(error);
      return false;
    }
  }

  Future<PaymentMethod?> activatePaymentMethod(PaymentMethod method) async {
    if (await setPaymentMethodActive(method.id, true)) {
      return paymentMethodsById[method.id];
    }
    return null;
  }

  Future<PaymentMethod?> checkPaymentMethodDuplicate(String name) =>
      paymentMethodRepo.checkDuplicate(name);

  String _paymentSaveError(Object error) {
    if (error is ApiException && error.statusCode == 409) {
      paymentMethodNameError =
          'Способ оплаты с таким названием уже существует.';
      return paymentMethodNameError!;
    }
    if (error is ApiException && error.statusCode == 404) {
      return 'Способ оплаты не найден. Обновите список.';
    }
    return 'Не удалось сохранить способ оплаты. Повторите попытку.';
  }

  Future<Product?> addProduct({
    required String name,
    required double basePrice,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty || basePrice < 0) {
      return null;
    }

    productErrorMessage = null;
    try {
      final request = CreateProductRequest(
        name: normalizedName,
        basePrice: basePrice,
      );

      final created = await productRepo.createProduct(request);

      products.insert(0, created);

      notifyListeners();

      return created;
    } catch (error) {
      productErrorMessage = _productSaveError(error);
      return null;
    }
  }

  Future<bool> updateProduct(
    String id, {
    required String name,
    required double basePrice,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty || basePrice < 0) {
      return false;
    }

    productErrorMessage = null;
    try {
      final request = UpdateProductRequest(
        name: normalizedName,
        basePrice: basePrice,
      );

      final updated = await productRepo.updateProduct(id, request);

      _applyProduct(updated);

      return true;
    } catch (error) {
      productErrorMessage = _productSaveError(error);
      return false;
    }
  }

  Future<bool> setProductActive(String id, bool isActive) async {
    productErrorMessage = null;
    try {
      final updated = await productRepo.updateProduct(
        id,
        UpdateProductRequest(isActive: isActive),
      );
      _applyProduct(updated);
      return true;
    } catch (error) {
      productErrorMessage = _productSaveError(error);
      return false;
    }
  }

  Future<Product?> checkProductDuplicate(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;
    return await productRepo.checkDuplicate(cleanName);
  }

  Future<Product?> activateProduct(Product product) async {
    productErrorMessage = null;
    try {
      final updated = await productRepo.updateProduct(
        product.id,
        const UpdateProductRequest(isActive: true),
      );
      _applyProduct(updated);
      return updated;
    } catch (error) {
      productErrorMessage = _productSaveError(error);
      return null;
    }
  }

  String _productSaveError(Object error) {
    if (error is ApiException && error.statusCode == 409) {
      return 'Товар с таким названием уже существует.';
    }
    return 'Не удалось сохранить товар. Повторите попытку.';
  }
}
