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
}
