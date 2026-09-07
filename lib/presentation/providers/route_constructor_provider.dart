import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/constructor_directory_repo.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_route/delivery_route_repository.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_route/models/delivery_task_item_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/delivery_route/models/route_point_model.dart';
import 'package:mountain_fairytale/infrastructure/repos/products/models/product_model.dart';

class RouteConstructorProvider extends ChangeNotifier {
  final ConstructorDirectoryRepository _directoryRepo;
  final DeliveryRouteRepository _routeRepo;

  RouteConstructorProvider({
    required ConstructorDirectoryRepository directoryRepo,
    required DeliveryRouteRepository routeRepo,
  }) : _directoryRepo = directoryRepo,
       _routeRepo = routeRepo;

  // Справочники
  List<Car> cars = [];
  List<Product> products = [];
  bool isLoadingDirectories = false;

  // Поля формы маршрутного листа
  DateTime selectedDate = DateTime.now();
  String driverName = '';
  Car? selectedCar;
  double startMileage = 0.0;

  // Список точек (наш изменяемый порядок объезда)
  List<RoutePoint> points = [];

  double get grandTotal => points.fold(0.0, (sum, p) => sum + p.totalAmount);

  Future<void> loadDirectories() async {
    isLoadingDirectories = true;
    notifyListeners();
    try {
      cars = await _directoryRepo.getAvailableCars();
      products = await _directoryRepo.getAvailableProducts();
    } catch (_) {}
    isLoadingDirectories = false;
    notifyListeners();
  }

  void setDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  void addClientPoint(Client client) {
    // Предотвращаем дублирование клиента в рамках одного выезда (бизнес-логика)
    if (points.any((p) => p.clientId == client.id)) return;

    points.add(
      RoutePoint(
        clientId: client.id,
        clientName: client.name,
        city: 'г. Ставрополь',
        // Можно извлекать парсингом или добавить в модель
        address: client.address,
        phone: client.phone,
        paymentMethod: 'Наличные',
        // Дефолт
        salesRepresentative: 'Основной менеджер',
        // Дефолт
        items: [],
      ),
    );
    notifyListeners();
  }

  void removePoint(int index) {
    points.removeAt(index);
    notifyListeners();
  }

  // Изменение порядка точек через Drag and Drop
  void reorderPoints(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final RoutePoint item = points.removeAt(oldIndex);
    points.insert(newIndex, item);
    notifyListeners();
  }

  void addTaskToPoint(int pointIndex, Product product, int quantity) {
    final currentPoint = points[pointIndex];
    final updatedItems = List<DeliveryTaskItem>.from(currentPoint.items);

    // Если такой товар уже есть у клиента — увеличиваем количество, иначе добавляем новый
    final existingIndex = updatedItems.indexWhere(
      (i) => i.productId == product.id,
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

  void updatePointMeta(
    int pointIndex, {
    String? paymentMethod,
    String? salesRep,
  }) {
    final p = points[pointIndex];
    points[pointIndex] = RoutePoint(
      clientId: p.clientId,
      clientName: p.clientName,
      city: p.city,
      address: p.address,
      phone: p.phone,
      paymentMethod: paymentMethod ?? p.paymentMethod,
      salesRepresentative: salesRep ?? p.salesRepresentative,
      items: p.items,
    );
    notifyListeners();
  }

  Future<bool> saveRoute() async {
    if (selectedCar == null || driverName.trim().isEmpty || points.isEmpty)
      return false;

    final sheet = DeliveryRouteSheet(
      date: selectedDate,
      driverName: driverName.trim(),
      carId: selectedCar!.id,
      carModelAndNumber: '${selectedCar!.model} (${selectedCar!.number})',
      startMileage: startMileage,
      points: points,
    );

    try {
      await _routeRepo.saveRouteSheet(sheet);
      return true;
    } catch (_) {
      return false;
    }
  }
}
