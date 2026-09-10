import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/services.dart';
import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_task_item_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/route_point_model.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos.dart';

class RouteConstructorProvider extends ChangeNotifier {
  final CarRepository _carRepo;
  final DriverRepository _driverRepo;
  final ProductRepository _productRepo;
  final DeliveryRouteRepository _routeRepo;
  final RoutePrintService _printService;

  RouteConstructorProvider({
    required CarRepository carRepo,
    required DriverRepository driverRepo,
    required ProductRepository productRepo,
    required DeliveryRouteRepository routeRepo,
    required RoutePrintService printService,
  })
      : _carRepo = carRepo,
        _driverRepo = driverRepo,
        _productRepo = productRepo,
        _routeRepo = routeRepo,
        _printService = printService;

  List<Car> cars = [];
  List<Driver> drivers = [];
  List<Product> products = [];

  bool isLoadingDirectories = false;
  bool isReadOnly = false;

  DateTime selectedDate = DateTime.now();
  String driverName = '';
  Driver? selectedDriver;
  Car? selectedCar;
  double startMileage = 0.0;
  List<RoutePoint> points = [];

  double get grandTotal => points.fold(0.0, (sum, p) => sum + p.totalAmount);

  void resetForm() {
    selectedDate = DateTime.now();
    driverName = '';
    selectedDriver = null;
    selectedCar = null;
    startMileage = 0.0;
    points = [];
    isReadOnly = false;
    notifyListeners();
  }

  Future<void> loadDirectories() async {
    isLoadingDirectories = true;
    notifyListeners();

    try {
      cars = await _carRepo.getAvailableCars();
      drivers = await _driverRepo.getAvailableDrivers();
      products = await _productRepo.getAvailableProducts();
    } catch (_) {}

    isLoadingDirectories = false;
    notifyListeners();
  }

  void selectDriver(Driver? driver) {
    selectedDriver = driver;
    driverName = driver?.name ?? '';
    notifyListeners();
  }

  void selectCar(Car? car) {
    selectedCar = car;
    notifyListeners();
  }

  void setDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  void addClientPoint(Client client) {
    if (points.any((p) => p.clientId == client.id)) return;

    points.add(
      RoutePoint(
        clientId: client.id,
        clientName: client.name,
        city: 'г. Ставрополь',
        address: client.address,
        phone: client.phone,
        paymentMethod: 'Наличные',
        salesRepresentative: 'Основной менеджер',
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
    final RoutePoint item = points.removeAt(oldIndex);
    points.insert(newIndex, item);
    notifyListeners();
  }

  void addTaskToPoint(int pointIndex, Product product, int quantity) {
    final currentPoint = points[pointIndex];
    final updatedItems = List<DeliveryTaskItem>.from(currentPoint.items);

    final existingIndex = updatedItems.indexWhere((i) =>
    i.productId == product.id);
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

  void updatePointMeta(int pointIndex,
      {String? paymentMethod, String? salesRep}) {
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
    final sheet = currentRouteSheet;

    if (sheet == null) {
      return false;
    }

    try {
      await _routeRepo.saveRouteSheet(sheet);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Driver?> addDriver(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return null;

    try {
      // Репозиторий теперь ждет модель, передаем временный инстанс (ID назначит сервер/сорс)
      final driverModel = Driver(id: 0, name: normalizedName);
      final createdDriver = await _driverRepo.createDriver(driverModel);

      drivers.insert(0, createdDriver);
      selectDriver(createdDriver);
      return createdDriver;
    } catch (_) {
      return null;
    }
  }

  Future<Car?> addCar({required String model, required String number}) async {
    final normalizedModel = model.trim();
    final normalizedNumber = number.trim();
    if (normalizedModel.isEmpty || normalizedNumber.isEmpty) return null;

    try {
      final carModel = Car(
          id: 0, model: normalizedModel, number: normalizedNumber);
      final createdCar = await _carRepo.createCar(carModel);

      cars.insert(0, createdCar);
      selectCar(createdCar);
      return createdCar;
    } catch (_) {
      return null;
    }
  }

  /// Загружает существующий маршрут по дате дня доставки
  Future<void> loadExistingRoute(DateTime date) async {
    isLoadingDirectories = true;
    notifyListeners();

    try {
      // 1. Сначала загружаем справочники (машины, водители, продукты)
      cars = await _carRepo.getAvailableCars();
      drivers = await _driverRepo.getAvailableDrivers();
      products = await _productRepo.getAvailableProducts();

      // 2. Устанавливаем режим "Только для чтения", если дата не сегодняшняя
      final now = DateTime.now();
      isReadOnly = !(date.year == now.year && date.month == now.month &&
          date.day == now.day);
      selectedDate = date;

      // 3. Запрашиваем все маршрутные листы из репозитория
      final allSheets = await _routeRepo.getRouteSheets();

      // Ищем маршрут, у которого совпадает дата (день, месяц, год)
      final existingSheet = allSheets.firstWhere(
            (sheet) =>
        sheet.date.year == date.year &&
            sheet.date.month == date.month &&
            sheet.date.day == date.day,
      );

      // 4. Наполняем стейт провайдера данными из найденного маршрутного листа
      startMileage = existingSheet.startMileage;
      points = List.from(existingSheet.points);

      // Восстанавливаем выбранного водителя
      selectedDriver = drivers.firstWhere(
            (d) => d.name == existingSheet.driverName,
        orElse: () => Driver(id: 0, name: existingSheet.driverName),
      );
      driverName = selectedDriver?.name ?? '';

      // Восстанавливаем выбранный автомобиль
      try {
        selectedCar = cars.firstWhere((c) => c.id == existingSheet.carId);
      } catch (_) {
        // Если машина с таким ID не найдена, берем первую доступную или оставляем null
        selectedCar = cars.isNotEmpty ? cars.first : null;
      }
    } catch (e) {
      // Если маршрутный лист для этого дня не найден в демо-базе,
      // оставляем форму пустой на эту дату (или можно показать ошибку)
      points = [];
      selectedDriver = null;
      selectedCar = null;
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  /// Возвращает список всех маршрутных листов за указанную дату
  Future<List<DeliveryRouteSheet>> getRouteSheetsByDate(DateTime date) async {
    try {
      final allSheets = await _routeRepo.getRouteSheets();
      return allSheets.where((sheet) =>
      sheet.date.year == date.year &&
          sheet.date.month == date.month &&
          sheet.date.day == date.day
      ).toList();
    } catch (_) {
      return const [];
    }
  }

  DeliveryRouteSheet? get currentRouteSheet {
    if (selectedDriver == null ||
        selectedCar == null ||
        points.isEmpty) {
      return null;
    }

    return DeliveryRouteSheet(
      date: selectedDate,
      driverName: selectedDriver!.name,
      carId: selectedCar!.id,
      carModelAndNumber:
      '${selectedCar!.model} (${selectedCar!.number})',
      startMileage: startMileage,
      points: points,
    );
  }

  Future<bool> printRoute() async {
    final sheet = currentRouteSheet;

    if (sheet == null) {
      return false;
    }

    try {
      await _printService.printRouteSheet(sheet);
      return true;
    } catch (_) {
      return false;
    }
  }

}
