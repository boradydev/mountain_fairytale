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
    required this._carRepo,
    required this._driverRepo,
    required DeliveryRouteRepository routeRepo,
    required this._printService,
    // Поля родителя передаем напрямую через super.
    required super.productRepo,
    required super.paymentMethodRepo,
    required super.clientRepo,
  }) : _routeRepo = routeRepo,
       super(lockRepository: routeRepo);

  DeliveryRouteSheet? _savedSheet;
  Future<({double? mileage})?> Function(Car car, DeliveryRouteSheet sheet)?
  confirmCarReplacement;
  bool _carChangeConfirmed = false;
  double? _previousCarMileage;
  int mileageRevision = 0;
  int _selectionVersion = 0;

  double? get distance {
    final end = endMileage;
    if (end == null ||
        !end.isFinite ||
        !startMileage.isFinite ||
        startMileage < 0 ||
        end < startMileage) {
      return null;
    }
    return end - startMileage;
  }

  void useCurrentMileage() {
    if (!canEdit || selectedCar == null) return;
    _startMileage = selectedCar!.currentMileage;
    mileageRevision++;
    notifyListeners();
  }

  bool get assignmentUnchanged =>
      _savedSheet != null &&
      selectedDate == _savedSheet!.date &&
      selectedDriver?.id == _savedSheet!.driverId &&
      selectedCar?.id == _savedSheet!.carId;

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
      if (previousSelection != null &&
          previousSelection.id == _savedSheet?.carId &&
          !loaded.any((car) => car.id == previousSelection.id)) {
        loaded.add(previousSelection);
      }
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
          (car) =>
              car.id == selectedId &&
              (car.isActive || car.id == _savedSheet?.carId),
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
    if (car.isActive || showInactiveCars || car.id == _savedSheet?.carId) {
      cars.insert(0, car);
    }
    if (selectedCar?.id == car.id) {
      if (car.isActive || car.id == _savedSheet?.carId) {
        selectedCar = car;
      } else {
        selectedCar = null;
      }
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
      return await selectCar(updated);
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
      if (previousSelection != null &&
          previousSelection.id == _savedSheet?.driverId &&
          !loaded.any((driver) => driver.id == previousSelection.id)) {
        loaded.add(previousSelection);
      }
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
        final matches = drivers.where(
          (d) =>
              d.id == selectedId &&
              (d.isActive || d.id == _savedSheet?.driverId),
        );
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
    if (driver.isActive ||
        showInactiveDrivers ||
        driver.id == _savedSheet?.driverId) {
      drivers.insert(0, driver);
    }
    if (selectedDriver?.id == driver.id) {
      if (driver.isActive || driver.id == _savedSheet?.driverId) {
        selectedDriver = driver;
        driverName = driver.name;
      } else {
        selectedDriver = null;
        driverName = '';
      }
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
  double _startMileage = 0.0;
  double? _endMileage;
  double get startMileage => _startMileage;
  set startMileage(double value) {
    _startMileage = value;
    notifyListeners();
  }

  double? get endMileage => _endMileage;
  set endMileage(double? value) {
    _endMileage = value;
    notifyListeners();
  }

  String? get currentRouteId => documentId;

  void resetForm() {
    initializeDocumentSession();
    _savedSheet = null;
    _carChangeConfirmed = false;
    _previousCarMileage = null;
    _selectionVersion++;
    mileageRevision++;
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

      await loadProducts();
      await loadPaymentMethods();
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  void selectDriver(Driver? driver) {
    if (!canEdit) return;
    if (driver != null && !driver.isActive) return;
    selectedDriver = driver;
    driverName = driver?.name ?? '';
    notifyListeners();
  }

  void selectExistingDriver(Driver driver) {
    if (!driver.isActive) return;
    _applyDriver(driver);
    selectDriver(driver);
  }

  Future<bool> selectCar(Car? car) async {
    if (!canEdit) return false;
    if (car != null && !car.isActive) return false;
    if (selectedCar?.id == car?.id) return true;
    final version = ++_selectionVersion;
    if (car != null) {
      try {
        car = await _carRepo.getCarById(car.id);
      } catch (error) {
        handleDocumentError(error);
        return false;
      }
      if (version != _selectionVersion || !canEdit || !car.isActive) {
        return false;
      }
    }
    final saved = _savedSheet;
    if (saved?.endMileage != null &&
        car?.id != saved!.carId &&
        !_carChangeConfirmed) {
      final confirm = confirmCarReplacement;
      if (confirm == null) return false;
      try {
        final previous = await _carRepo.getCarById(saved.carId);
        if (version != _selectionVersion || !canEdit) return false;
        final result = await confirm(previous, saved);
        if (result == null || version != _selectionVersion || !canEdit) {
          return false;
        }
        _carChangeConfirmed = true;
        _previousCarMileage = result.mileage;
      } catch (error) {
        handleDocumentError(error);
        return false;
      }
    }
    if (car?.id == saved?.carId) {
      // Keep acknowledgement for this edit session, but discard the correction.
      _previousCarMileage = null;
    }
    _startMileage = car?.currentMileage ?? 0;
    _endMileage = null;
    mileageRevision++;
    if (car != null) {
      cars = [car, ...cars.where((existing) => existing.id != car!.id)];
    }
    selectedCar = car;
    notifyListeners();
    return true;
  }

  Future<void> selectExistingCar(Car car) async {
    if (!car.isActive) return;
    _applyCar(car);
    await selectCar(car);
  }

  void setDate(DateTime date) {
    if (!canEdit) return;
    selectedDate = date;
    notifyListeners();
  }

  Future<bool> saveRoute() async {
    if (!canSave) {
      return false;
    }
    final sheet = currentRouteSheet;
    if (sheet == null) {
      documentError =
          'Проверьте назначение водителя и автомобиля, дату и пробег.';
      notifyListeners();
      return false;
    }
    final creating = documentId == null;
    documentBusy = true;
    documentError = null;
    notifyListeners();
    try {
      final saved = await _routeRepo.saveRouteSheet(sheet);
      documentId = saved.id;
      documentCreatedAt = saved.createdAt;
      _savedSheet = saved;
      _carChangeConfirmed = false;
      _previousCarMileage = null;
      points = List.from(saved.points);
      markDocumentSaved(created: creating);
      return true;
    } catch (error) {
      handleDocumentError(error);
      return false;
    } finally {
      documentBusy = false;
      notifyListeners();
    }
  }

  Future<bool> changeDocumentActive() async {
    if (documentId == null || documentBusy) {
      return false;
    }
    documentBusy = true;
    documentError = null;
    notifyListeners();
    try {
      final saved = documentActive
          ? await _routeRepo.cancelRouteSheet(documentId!)
          : await _routeRepo.restoreRouteSheet(documentId!);
      initializeDocumentSession(
        id: saved.id,
        createdAt: saved.createdAt,
        active: saved.isActive,
      );
      documentChanged = true;
      documentBusy = true;
      await _applySheet(saved);
      return true;
    } catch (error) {
      handleDocumentError(error);
      return false;
    } finally {
      documentBusy = false;
      notifyListeners();
    }
  }

  Future<Driver?> addDriver(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

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
    if (normalizedName.isEmpty) {
      return false;
    }

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
    if (normalizedModel.isEmpty || normalizedNumber.isEmpty) {
      return null;
    }

    try {
      final request = CreateCarRequest(
        model: normalizedModel,
        number: normalizedNumber,
        currentMileage: currentMileage,
      );
      final createdCar = await _carRepo.createCar(request);

      cars.insert(0, createdCar);
      await selectCar(createdCar);
      return createdCar;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCar(
    String id, {
    String? model,
    String? number,
    double? currentMileage,
  }) async {
    final normalizedModel = model?.trim();
    final normalizedNumber = number?.trim();
    if ((normalizedModel != null && normalizedModel.isEmpty) ||
        (normalizedNumber != null && normalizedNumber.isEmpty)) {
      return false;
    }

    try {
      final request = UpdateCarRequest(
        model: normalizedModel,
        number: normalizedNumber,
        currentMileage: currentMileage,
      );
      final updatedCar = await _carRepo.updateCar(id, request);

      _applyCar(updatedCar);
      await selectCar(updatedCar);
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

  Future<void> _applySheet(DeliveryRouteSheet sheet) async {
    // Resolve both resources before publishing the selection. Dropdown values
    // must remain in their item lists throughout asynchronous loading.
    final driver = await _driverRepo.getDriverById(sheet.driverId!);
    final car = await _carRepo.getCarById(sheet.carId);
    _savedSheet = sheet;
    _carChangeConfirmed = false;
    _previousCarMileage = null;
    _selectionVersion++;
    mileageRevision++;
    documentId = sheet.id;
    documentCreatedAt = sheet.createdAt;
    documentActive = sheet.isActive;
    selectedDate = sheet.date;
    startMileage = sheet.startMileage;
    endMileage = sheet.endMileage;
    driverName = sheet.driverName;
    points = List.from(sheet.points);
    selectedDriver = driver;
    selectedCar = car;
    drivers = [
      selectedDriver!,
      ...drivers.where((d) => d.id != selectedDriver!.id),
    ];
    cars = [selectedCar!, ...cars.where((c) => c.id != selectedCar!.id)];
    isOldDocument = DateTime.now().difference(sheet.date).inDays >= 7;
  }

  Future<void> loadExistingRouteById(String routeId) async {
    resetForm();
    initializeDocumentSession(id: routeId);
    isLoadingDirectories = true;
    notifyListeners();
    try {
      await loadDirectories();
      final sheet = await _routeRepo.getRouteSheetById(routeId);
      await _applySheet(sheet);
    } catch (error) {
      documentError = documentFailure(error);
      isEditing = false;
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  @override
  Future<void> refreshForEditing() async {
    await _applySheet(await _routeRepo.getRouteSheetById(documentId!));
  }

  Future<List<DeliveryRouteSheet>> getRouteSheetsByDate(DateTime date) async =>
      (await _routeRepo.getRouteSheets())
          .where(
            (sheet) =>
                sheet.date.year == date.year &&
                sheet.date.month == date.month &&
                sheet.date.day == date.day,
          )
          .toList();

  DeliveryRouteSheet? get currentRouteSheet {
    if (selectedDriver == null ||
        (!selectedDriver!.isActive && !assignmentUnchanged) ||
        selectedCar == null ||
        (!selectedCar!.isActive && !assignmentUnchanged)) {
      return null;
    }

    return DeliveryRouteSheet(
      id: currentRouteId,
      createdAt: documentCreatedAt,
      isActive: documentActive,
      // Применится существующий ID или null при создании нового
      date: selectedDate,
      driverName: selectedDriver!.name,
      driverId: selectedDriver!.id,
      carId: selectedCar!.id,
      carModelAndNumber:
          '${selectedCar!.model} (${formatCarNumber(selectedCar!.number)})',
      startMileage: startMileage,
      endMileage: endMileage,
      carChangeConfirmed:
          _carChangeConfirmed && selectedCar!.id != _savedSheet?.carId,
      previousCarMileage: _previousCarMileage,
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
