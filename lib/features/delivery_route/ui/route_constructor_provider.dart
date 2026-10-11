import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/cars/cars_abcs.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';
import 'package:mountain_fairytale/features/drivers/drivers_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';

class RouteConstructorProvider extends OrderPointsProvider {
  // 1. Объявляем ТОЛЬКО свои собственные репозитории, которых нет в родителе
  final CarRepository _carRepo;
  final DriverRepository _driverRepo;
  final DeliveryRouteRepository _routeRepo;
  final RoutePrintService _printService;

  // 2. Инициализируем всё в одно действие
  RouteConstructorProvider({
    required CarRepository carRepo,
    required DriverRepository driverRepo,
    required DeliveryRouteRepository routeRepo,
    required RoutePrintService printService,
    // Поля родителя передаем напрямую через super.
    required super.productRepo,
    required super.paymentMethodRepo,
    required super.clientRepo,
  }) : _carRepo = carRepo,
       _driverRepo = driverRepo,
       _routeRepo = routeRepo,
       _printService = printService;

  List<Car> cars = [];
  List<Driver> drivers = [];
  bool showInactiveCars = false;
  bool isLoadingCars = false;
  String? carError;
  int _carLoadVersion = 0;
  bool showInactiveDrivers = false;
  bool isLoadingDrivers = false;
  String? driverError;
  int _driverLoadVersion = 0;

  Future<void> loadCars() async {
    final version = ++_carLoadVersion;
    isLoadingCars = true;
    carError = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      showInactiveCars = prefs.getBool('show_inactive_cars') ?? false;
      final loaded = await _carRepo.getAvailableCars(
        includeDeactivated: showInactiveCars,
      );
      if (version != _carLoadVersion) return;
      final previousSelection = selectedCar;
      cars = loaded.map((car) {
        if (previousSelection != null &&
            car.id == previousSelection.id &&
            car.model == previousSelection.model &&
            car.number == previousSelection.number &&
            car.currentMileage == previousSelection.currentMileage &&
            car.isActive == previousSelection.isActive) {
          return previousSelection;
        }
        return car;
      }).toList();
      final selectedId = selectedCar?.id;
      if (selectedId != null) {
        final matches = cars.where(
          (car) => car.id == selectedId && car.isActive,
        );
        selectedCar = matches.isEmpty ? null : matches.first;
        if (selectedCar == null) startMileage = 0;
      }
    } catch (_) {
      if (version == _carLoadVersion) {
        carError = 'Не удалось загрузить автомобили. Повторите попытку.';
      }
    } finally {
      if (version == _carLoadVersion) {
        isLoadingCars = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleInactiveCars(bool value) async {
    if (isLoadingCars) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_inactive_cars', value);
    await loadCars();
  }

  void _applyCar(Car car) {
    cars = cars.where((existing) => existing.id != car.id).toList();
    if (car.isActive || showInactiveCars) cars.insert(0, car);
    if (selectedCar?.id == car.id) {
      selectCar(car.isActive ? car : null);
      if (!car.isActive) startMileage = 0;
    }
    notifyListeners();
  }

  Future<bool> activateAndSelectCar(Car car) async {
    try {
      final updated = await _carRepo.updateCar(
        car.id,
        const UpdateCarRequest(isActive: true),
      );
      _applyCar(updated);
      selectCar(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadDrivers() async {
    final version = ++_driverLoadVersion;
    isLoadingDrivers = true;
    driverError = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      showInactiveDrivers = prefs.getBool('show_inactive_drivers') ?? false;
      final loaded = await _driverRepo.getAvailableDrivers(
        includeDeactivated: showInactiveDrivers,
      );
      if (version != _driverLoadVersion) return;
      final previousSelection = selectedDriver;
      // Reuse an unchanged selection so the dropdown keeps its form state and
      // focus when a refreshed API response creates new model instances.
      drivers = loaded.map((driver) {
        if (previousSelection != null &&
            driver.id == previousSelection.id &&
            driver.name == previousSelection.name &&
            driver.isActive == previousSelection.isActive &&
            driver.createdAt == previousSelection.createdAt) {
          return previousSelection;
        }
        return driver;
      }).toList();
      final selectedId = selectedDriver?.id;
      if (selectedId != null) {
        final matches = drivers.where((d) => d.id == selectedId && d.isActive);
        selectedDriver = matches.isEmpty ? null : matches.first;
        driverName = selectedDriver?.name ?? '';
      }
    } catch (_) {
      if (version == _driverLoadVersion) {
        driverError = 'Не удалось загрузить водителей. Повторите попытку.';
      }
    } finally {
      if (version == _driverLoadVersion) {
        isLoadingDrivers = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleInactiveDrivers(bool value) async {
    if (isLoadingDrivers) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_inactive_drivers', value);
    await loadDrivers();
  }

  void _applyDriver(Driver driver) {
    drivers = drivers.where((d) => d.id != driver.id).toList();
    if (driver.isActive || showInactiveDrivers) drivers.insert(0, driver);
    if (selectedDriver?.id == driver.id) {
      selectDriver(driver.isActive ? driver : null);
    }
    notifyListeners();
  }

  Future<bool> activateAndSelectDriver(Driver driver) async {
    try {
      final updated = await _driverRepo.updateDriver(
        driver.id,
        const UpdateDriverRequest(isActive: true),
      );
      _applyDriver(updated);
      selectDriver(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

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
      await loadCars();
      await loadDrivers();

      products = await productRepo.getAvailableProducts();
      paymentMethods = await paymentMethodRepo.getAllPaymentMethods();
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  void selectDriver(Driver? driver) {
    if (driver != null && !driver.isActive) return;
    selectedDriver = driver;
    driverName = driver?.name ?? '';
    notifyListeners();
  }

  void selectCar(Car? car) {
    if (car != null && !car.isActive) return;
    selectedCar = car;
    if (car != null) {
      startMileage = car.currentMileage;
    }
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

  Future<bool> updateDriver(String id, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;

    try {
      final request = UpdateDriverRequest(name: normalizedName);
      final updatedDriver = await _driverRepo.updateDriver(id, request);

      _applyDriver(updatedDriver);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deactivateDriver(String id) async {
    try {
      final updated = await _driverRepo.updateDriver(
        id,
        const UpdateDriverRequest(isActive: false),
      );
      _applyDriver(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Driver?> checkDriverDuplicate(String name) async {
    return _driverRepo.checkDuplicate(name);
  }

  Future<Car?> addCar({
    required String model,
    required String number,
    double currentMileage = 0.0,
  }) async {
    final normalizedModel = model.trim();
    final normalizedNumber = number.trim();
    if (normalizedModel.isEmpty || normalizedNumber.isEmpty) return null;

    try {
      final request = CreateCarRequest(
        model: normalizedModel,
        number: normalizedNumber,
        currentMileage: currentMileage,
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
    String id, {
    required String model,
    required String number,
    double? currentMileage,
  }) async {
    final normalizedModel = model.trim();
    final normalizedNumber = number.trim();
    if (normalizedModel.isEmpty || normalizedNumber.isEmpty) return false;

    try {
      final request = UpdateCarRequest(
        model: normalizedModel,
        number: normalizedNumber,
        currentMileage: currentMileage,
      );
      final updatedCar = await _carRepo.updateCar(id, request);

      _applyCar(updatedCar);
      selectCar(updatedCar);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deactivateCar(String id) async {
    try {
      final updated = await _carRepo.deactivateCar(id);
      _applyCar(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Car?> checkCarDuplicate(String number) async {
    return _carRepo.checkDuplicate(number);
  }

  Future<void> loadExistingRouteById(int routeId) async {
    isLoadingDirectories = true;
    notifyListeners();
    try {
      await loadCars();
      await loadDrivers();
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

      final matches = drivers
          .where(
            (d) =>
                d.isActive &&
                (sheet.driverId != null
                    ? d.id == sheet.driverId
                    : d.name == sheet.driverName),
          )
          .toList();
      // Legacy demo routes only store names. Do not invent an API identity or
      // guess between different people with the same name.
      selectedDriver = matches.length == 1 ? matches.single : null;
      driverName = selectedDriver?.name ?? sheet.driverName;

      try {
        selectedCar = cars.firstWhere((c) => c.id == sheet.carId && c.isActive);
      } catch (_) {
        selectedCar = null;
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
    if (selectedDriver == null ||
        !selectedDriver!.isActive ||
        selectedCar == null ||
        !selectedCar!.isActive ||
        points.isEmpty) {
      return null;
    }

    return DeliveryRouteSheet(
      id: currentRouteId,
      // Применится существующий ID или null при создании нового
      date: selectedDate,
      driverName: selectedDriver!.name,
      driverId: selectedDriver!.id,
      carId: selectedCar!.id,
      carModelAndNumber:
          '${selectedCar!.model} (${formatCarNumber(selectedCar!.number)})',
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
