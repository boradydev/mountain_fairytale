import 'package:mountain_fairytale/features/pickup/data/pickup_model.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';

class PickupConstructorProvider extends OrderPointsProvider {
  final PickupRepository _pickupRepo;
  PickupConstructorProvider({
    required PickupRepository pickupRepo,
    required super.productRepo,
    required super.paymentMethodRepo,
    required super.clientRepo,
  }) : _pickupRepo = pickupRepo,
       super(lockRepository: pickupRepo);
  DateTime selectedDate = DateTime.now();
  String? get currentPickupId => documentId;
  bool isOldDocument = false;
  void resetForm() {
    initializeDocumentSession();
    selectedDate = DateTime.now();
    points = [];
    isOldDocument = false;
    notifyListeners();
  }

  void setDate(DateTime date) {
    if (!canEdit) return;
    selectedDate = date;
    notifyListeners();
  }

  Future<void> loadDirectories() => loadOrderDirectories();
  void _applySheet(PickupSheet sheet) {
    documentId = sheet.id;
    documentRevision = sheet.revision;
    documentCreatedAt = sheet.createdAt;
    documentActive = sheet.isActive;
    selectedDate = sheet.date;
    points = List.from(sheet.points);
    isOldDocument = DateTime.now().difference(sheet.date).inDays >= 7;
  }

  Future<void> loadExistingPickupById(String id) async {
    resetForm();
    initializeDocumentSession(id: id);
    isLoadingDirectories = true;
    notifyListeners();
    try {
      await loadOrderDirectories();
      _applySheet(await _pickupRepo.getPickupSheetById(id));
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
    _applySheet(await _pickupRepo.getPickupSheetById(documentId!));
  }

  @override
  Future<RouteDocument?> readRecoveryDocument() =>
      _pickupRepo.getPickupSheetById(documentId!);

  @override
  Future<RouteDocument?> findPendingCreation(String requestId) async {
    try {
      return await _pickupRepo.findCreatedPickup(requestId);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> applyRecoveryDocument(RouteDocument document) async =>
      _applySheet(document as PickupSheet);

  PickupSheet get currentPickupSheet => PickupSheet(
    id: documentId,
    revision: documentRevision,
    saveOperationId: saveOperationId,
    createdAt: documentCreatedAt,
    isActive: documentActive,
    date: selectedDate,
    points: points,
  );
  Future<bool> savePickup() async {
    if (!canSave) return false;
    final creating = documentId == null;
    documentBusy = true;
    documentError = null;
    notifyListeners();
    try {
      prepareDocumentSave();
      _applySheet(await _pickupRepo.savePickupSheet(currentPickupSheet));
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
    if (documentId == null || documentBusy) return false;
    documentBusy = true;
    documentError = null;
    notifyListeners();
    try {
      final saved = documentActive
          ? await _pickupRepo.cancelPickupSheet(documentId!)
          : await _pickupRepo.restorePickupSheet(documentId!);
      _applySheet(saved);
      initializeDocumentSession(
        id: saved.id,
        createdAt: saved.createdAt,
        active: saved.isActive,
        revision: saved.revision,
      );
      documentChanged = true;
      return true;
    } catch (error) {
      handleDocumentError(error);
      return false;
    } finally {
      documentBusy = false;
      notifyListeners();
    }
  }

  Future<List<PickupSheet>> getPickupSheetsByDate(DateTime date) async =>
      (await _pickupRepo.getPickupSheets())
          .where(
            (sheet) =>
                sheet.date.year == date.year &&
                sheet.date.month == date.month &&
                sheet.date.day == date.day,
          )
          .toList();
}
