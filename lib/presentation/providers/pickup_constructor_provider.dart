import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/route_point_model.dart';
import 'package:mountain_fairytale/infra/repos/payment_methods/models/payment_method_model.dart';
import 'package:mountain_fairytale/infra/repos/pickup/models/pickup_sheet_model.dart';
import 'package:mountain_fairytale/infra/repos/products/models/product_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/pickup.dart';
import 'package:mountain_fairytale/presentation/providers/order_points_provider.dart';

class PickupConstructorProvider extends OrderPointsProvider {
  final PickupRepository _pickupRepo;

  PickupConstructorProvider({
    required this._pickupRepo,
    required super.productRepo,
    required super.paymentMethodRepo,
    required super.clientRepo,
  });

  DateTime selectedDate = DateTime.now();

  int? currentPickupId;

  bool isReadOnly = false;

  void resetForm() {
    currentPickupId = null;
    selectedDate = DateTime.now();
    points = [];
    isReadOnly = false;

    notifyListeners();
  }

  void setDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  Future<void> loadDirectories() async {
    await loadOrderDirectories();
  }

  Future<void> loadExistingPickupById(int id) async {
    isLoadingDirectories = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        productRepo.getAvailableProducts(),
        paymentMethodRepo.getAllPaymentMethods(),
        _pickupRepo.getPickupSheetById(id),
      ]);

      products = results[0] as List<Product>;
      paymentMethods = results[1] as List<PaymentMethod>;

      final sheet = results[2] as PickupSheet;

      currentPickupId = sheet.id;
      selectedDate = sheet.date;
      points = List<RoutePoint>.from(sheet.points);

      isReadOnly = !DateUtils.isSameDay(sheet.date, DateTime.now());
    } finally {
      isLoadingDirectories = false;
      notifyListeners();
    }
  }

  PickupSheet? get currentPickupSheet {
    if (points.isEmpty) {
      return null;
    }

    return PickupSheet(id: currentPickupId, date: selectedDate, points: points);
  }

  Future<bool> savePickup() async {
    final sheet = currentPickupSheet;

    if (sheet == null) {
      return false;
    }

    try {
      final savedSheet = await _pickupRepo.savePickupSheet(sheet);

      currentPickupId = savedSheet.id;

      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePickup() async {
    if (currentPickupId == null) {
      return false;
    }

    try {
      await _pickupRepo.deletePickupSheet(currentPickupId!);

      resetForm();

      return true;
    } catch (_) {
      return false;
    }
  }
}
