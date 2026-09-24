import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_task_item_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/route_point_model.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/models/payment_method_model.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/client_contracts.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/payment_method_abcs.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/product_contracts.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';

abstract class OrderPointsProvider extends ChangeNotifier {
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
  List<PaymentMethod> paymentMethods = [];

  bool isLoadingDirectories = false;

  List<RoutePoint> points = [];

  String? newlyCreatedPaymentMethodName;

  double get grandTotal =>
      points.fold(0.0, (sum, point) => sum + point.totalAmount);

  Future<void> loadOrderDirectories() async {
    isLoadingDirectories = true;
    notifyListeners();

    try {
      products = await productRepo.getAvailableProducts();
      paymentMethods = await paymentMethodRepo.getAllPaymentMethods();
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  void addClientPoint(Client client) {
    if (points.any((p) => p.clientId == client.id)) {
      return;
    }

    points.add(
      RoutePoint(
        clientId: client.id,
        clientName: client.name,
        city: 'г. Ставрополь',
        address: client.address,
        phone: client.phone,
        paymentMethod: client.defaultPaymentMethod,
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
      paymentMethod: currentPoint.paymentMethod,
      salesRepresentative: currentPoint.salesRepresentative,
      items: items,
    );

    notifyListeners();
  }

  Future<void> updatePointMeta(
    int pointIndex,
    BuildContext context,
    ClientsProvider clientsProvider, {
    String? paymentMethod,
    String? salesRep,
  }) async {
    final point = points[pointIndex];

    final updatedPoint = RoutePoint(
      clientId: point.clientId,
      clientName: point.clientName,
      city: point.city,
      address: point.address,
      phone: point.phone,
      paymentMethod: paymentMethod ?? point.paymentMethod,
      salesRepresentative: salesRep ?? point.salesRepresentative,
      items: point.items,
    );

    points[pointIndex] = updatedPoint;
    notifyListeners();

    if (paymentMethod == null) {
      return;
    }

    try {
      final updatedClient = await clientRepo.updateClient(
        point.clientId,
        UpdateClientRequest(defaultPaymentMethod: paymentMethod),
      );

      clientsProvider.syncUpdatedClient(updatedClient);
    } catch (_) {}
  }

  // =========================================================================
  // МЕТОДЫ УПРАВЛЕНИЯ СПРАВОЧНИКОМ ФОРМ ОПЛАТЫ
  // =========================================================================

  Future<PaymentMethod?> addPaymentMethod(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return null;

    try {
      final request = CreatePaymentMethodRequest(name: normalizedName);
      final created = await paymentMethodRepo.createPaymentMethod(request);

      paymentMethods.insert(0, created);
      newlyCreatedPaymentMethodName = created.name;
      notifyListeners();
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updatePaymentMethod(int id, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;

    try {
      final request = UpdatePaymentMethodRequest(name: normalizedName);
      final updated = await paymentMethodRepo.updatePaymentMethod(id, request);

      paymentMethods = paymentMethods
          .map((p) => p.id == id ? updated : p)
          .toList();

      // Обновляем форму оплаты во всех точках текущего маршрута, если она там использовалась
      for (int i = 0; i < points.length; i++) {
        if (points[i].paymentMethod == points[i].paymentMethod) {
          // Сверяем по строке (или логике UI)
          // Дополнительное обновление метаданных при необходимости
        }
      }

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePaymentMethod(int id, String fallbackName) async {
    try {
      await paymentMethodRepo.deletePaymentMethod(id);
      paymentMethods = paymentMethods.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PaymentMethod?> checkPaymentMethodDuplicate(String name) async {
    try {
      final cleanName = name.trim().toLowerCase();
      if (cleanName.isEmpty) return null;

      final list = await paymentMethodRepo.getAllPaymentMethods();
      final duplicate = list.firstWhere(
        (p) => p.name.trim().toLowerCase() == cleanName,
      );
      return duplicate;
    } catch (_) {
      return null;
    }
  }

  Future<Product?> addProduct({
    required String name,
    required double basePrice,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty || basePrice < 0) {
      return null;
    }

    try {
      final request = CreateProductRequest(
        name: normalizedName,
        basePrice: basePrice,
      );

      final created = await productRepo.createProduct(request);

      products.insert(0, created);

      notifyListeners();

      return created;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProduct(
    int id, {
    required String name,
    required double basePrice,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty || basePrice < 0) {
      return false;
    }

    try {
      final request = UpdateProductRequest(
        name: normalizedName,
        basePrice: basePrice,
      );

      final updated = await productRepo.updateProduct(id, request);

      products = products
          .map((product) => product.id == id ? updated : product)
          .toList();

      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await productRepo.deleteProduct(id);

      products = products.where((product) => product.id != id).toList();

      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Product?> checkProductDuplicate(String name) async {
    try {
      final cleanName = name.trim().toLowerCase();

      if (cleanName.isEmpty) {
        return null;
      }

      final list = await productRepo.getAvailableProducts();

      return list.firstWhere(
        (product) => product.name.trim().toLowerCase() == cleanName,
      );
    } catch (_) {
      return null;
    }
  }
}
