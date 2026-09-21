import 'package:mountain_fairytale/infra/repos/cars/models/car_model.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/drivers/models/driver_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/car_contracts.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/delivery_route.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/driver_contracts.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/services.dart';
import 'package:mountain_fairytale/presentation/providers/order_points_provider.dart';

class RouteConstructorProvider extends OrderPointsProvider {
  // 1. Объявляем ТОЛЬКО свои собственные репозитории, которых нет в родителе
  final CarRepository _carRepo;
  final DriverRepository _driverRepo;
  final DeliveryRouteRepository _routeRepo;
  final RoutePrintService _printService;

  // 2. Инициализируем всё в одно действие
  RouteConstructorProvider({
    // Свои поля инициализируем через this._
    required this._carRepo,
    required this._driverRepo,
    required this._routeRepo,
    required this._printService,
    // Поля родителя передаем напрямую через super.
    required super.productRepo,
    required super.paymentMethodRepo,
    required super.clientRepo,
  });

  List<Car> cars = [];
  List<Driver> drivers = [];

  bool isOldDocument = false;

  DateTime selectedDate = DateTime.now();
  String driverName = '';
  Driver? selectedDriver;
  Car? selectedCar;
  double startMileage = 0.0;
  double? endMileage;

  int? currentRouteId;

  void resetForm() {
    currentRouteId = null;
    selectedDate = DateTime.now();
    driverName = '';
    selectedDriver = null;
    selectedCar = null;
    startMileage = 0.0;
    endMileage = null;
    points = [];
    isOldDocument = false;
    notifyListeners();
  }

  Future<void> loadDirectories() async {
    isLoadingDirectories = true;
    notifyListeners();

    try {
      cars = await _carRepo.getAvailableCars();
      drivers = await _driverRepo.getAvailableDrivers();

      products = await productRepo.getAvailableProducts();
      paymentMethods = await paymentMethodRepo.getAllPaymentMethods();
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
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

  Future<bool> saveRoute() async {
    final sheet = currentRouteSheet;

    if (sheet == null) {
      return false;
    }

    try {
      await _routeRepo.saveRouteSheet(sheet);

      if (endMileage != null && selectedCar != null) {
        final updatedCar = await _carRepo.updateCar(
          selectedCar!.id,
          UpdateCarRequest(
            currentMileage: endMileage,
          ),
        );

        cars = cars.map((car) {
          return car.id == updatedCar.id ? updatedCar : car;
        }).toList();

        selectedCar = updatedCar;
      }

      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Driver?> addDriver(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return null;

    try {
      final request = CreateDriverRequest(name: normalizedName);
      final createdDriver = await _driverRepo.createDriver(request);

      drivers.insert(0, createdDriver);
      selectDriver(createdDriver);
      return createdDriver;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateDriver(int id, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;

    try {
      final request = UpdateDriverRequest(name: normalizedName);
      final updatedDriver = await _driverRepo.updateDriver(id, request);

      drivers = drivers.map((d) => d.id == id ? updatedDriver : d).toList();
      selectDriver(updatedDriver);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteDriver(int id) async {
    try {
      await _driverRepo.deleteDriver(id);
      drivers = drivers.where((d) => d.id != id).toList();

      // Если удалили текущего выбранного водителя — зануляем поле дропдауна
      if (selectedDriver?.id == id) {
        selectDriver(null);
      } else {
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Driver?> checkDriverDuplicate(String name) async {
    try {
      return await _driverRepo.checkDuplicate(name);
    } catch (_) {
      return null;
    }
  }

  Future<Car?> addCar({required String model, required String number}) async {
    final normalizedModel = model.trim();
    final normalizedNumber = number.trim();
    if (normalizedModel.isEmpty || normalizedNumber.isEmpty) return null;

    try {
      final request = CreateCarRequest(
        model: normalizedModel,
        number: normalizedNumber,
      );
      final createdCar = await _carRepo.createCar(request);

      cars.insert(0, createdCar);
      selectCar(createdCar);
      return createdCar;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCar(
    int id, {
    required String model,
    required String number,
  }) async {
    final normalizedModel = model.trim();
    final normalizedNumber = number.trim();
    if (normalizedModel.isEmpty || normalizedNumber.isEmpty) return false;

    try {
      final request = UpdateCarRequest(
        model: normalizedModel,
        number: normalizedNumber,
      );
      final updatedCar = await _carRepo.updateCar(id, request);

      cars = cars.map((c) => c.id == id ? updatedCar : c).toList();
      selectCar(updatedCar);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCar(int id) async {
    try {
      await _carRepo.deleteCar(id);
      cars = cars.where((c) => c.id != id).toList();

      if (selectedCar?.id == id) {
        selectCar(null);
      } else {
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Car?> checkCarDuplicate(String number) async {
    try {
      return await _carRepo.checkDuplicate(number);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadExistingRouteById(int routeId) async {
    isLoadingDirectories = true;
    notifyListeners();
    try {
      cars = await _carRepo.getAvailableCars();
      drivers = await _driverRepo.getAvailableDrivers();
      products = await productRepo.getAvailableProducts();
      paymentMethods = await paymentMethodRepo.getAllPaymentMethods();

      // Запрашиваем конкретный маршрутный лист по ID
      final sheet = await _routeRepo.getRouteSheetById(routeId);

      currentRouteId = sheet.id;
      startMileage = sheet.startMileage;
      endMileage = sheet.endMileage;
      points = List.from(sheet.points);

      final now = DateTime.now();
      final difference = now.difference(sheet.date).inDays;
      isOldDocument = difference >= 7;

      selectedDriver = drivers.firstWhere(
        (d) => d.name == sheet.driverName,
        orElse: () => Driver(id: 0, name: sheet.driverName),
      );
      driverName = selectedDriver?.name ?? '';

      try {
        selectedCar = cars.firstWhere((c) => c.id == sheet.carId);
      } catch (_) {
        selectedCar = cars.isNotEmpty ? cars.first : null;
      }
    } catch (e) {
      points = [];
      selectedDriver = null;
      selectedCar = null;
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  Future<List<DeliveryRouteSheet>> getRouteSheetsByDate(DateTime date) async {
    try {
      final allSheets = await _routeRepo.getRouteSheets();
      return allSheets
          .where(
            (sheet) =>
                sheet.date.year == date.year &&
                sheet.date.month == date.month &&
                sheet.date.day == date.day,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  DeliveryRouteSheet? get currentRouteSheet {
    if (selectedDriver == null || selectedCar == null || points.isEmpty) {
      return null;
    }

    return DeliveryRouteSheet(
      id: currentRouteId,
      // Применится существующий ID или null при создании нового
      date: selectedDate,
      driverName: selectedDriver!.name,
      carId: selectedCar!.id,
      carModelAndNumber: '${selectedCar!.model} (${selectedCar!.number})',
      startMileage: startMileage,
      endMileage: endMileage,
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
