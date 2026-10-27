import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:mountain_fairytale/features/delivery_route/data/delivery_document_api.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
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
    this.lockRepository,
  });

  final DocumentLockRepository? lockRepository;
  String? documentId;
  DateTime? documentCreatedAt;
  bool documentActive = true;
  bool isEditing = true;
  bool documentBusy = false;
  String? documentError;
  String? lockOwner;
  bool documentChanged = false;
  int documentRevision = 1;
  bool connectionInterrupted = false;
  bool reconnecting = false;
  bool _saveUnconfirmed = false;
  String? _pendingOperationId;
  Timer? _connectionTimer;
  Future<bool>? _reconnectRequest;
  bool _checkingConnection = false;
  String? _discardReason;
  String get saveOperationId => _pendingOperationId ??= _newOperationId();

  void prepareDocumentSave() {
    saveOperationId;
    _saveUnconfirmed = true;
  }

  static String _newOperationId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  bool _draftStarted = false;
  bool _hasLock = false;
  bool _closing = false;
  bool _closed = false;
  int _sessionVersion = 0;
  Timer? _renewTimer;
  Future<void>? _renewRequest;
  Future<bool>? _acquireRequest;
  bool get canEdit =>
      isEditing &&
      documentActive &&
      !documentBusy &&
      !connectionInterrupted &&
      !_closed &&
      !_closing;
  bool get canSave => canEdit && !isLoadingDirectories;
  void initializeDocumentSession({
    String? id,
    DateTime? createdAt,
    bool active = true,
    int revision = 1,
  }) {
    _sessionVersion++;
    _renewTimer?.cancel();
    _connectionTimer?.cancel();
    documentRevision = revision;
    connectionInterrupted = false;
    reconnecting = false;
    _saveUnconfirmed = false;
    _pendingOperationId = null;
    _discardReason = null;
    documentId = id;
    documentCreatedAt = createdAt;
    documentActive = active;
    isEditing = id == null;
    _draftStarted = id == null;
    _hasLock = false;
    _closing = false;
    _closed = false;
    documentBusy = false;
    documentError = null;
    lockOwner = null;
    documentChanged = false;
  }

  void startConnectionWatch() {
    if (_closed || _connectionTimer?.isActive == true) return;
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConnection(),
    );
  }

  void stopConnectionWatch() => _connectionTimer?.cancel();

  void markDocumentSaved({required bool created}) {
    _saveUnconfirmed = false;
    _pendingOperationId = null;
    documentChanged = true;
    if (created) {
      isEditing = false;
      _draftStarted = false;
    }
  }

  Future<void> refreshForEditing() async {}
  Future<RouteDocument?> readRecoveryDocument() async => null;
  Future<RouteDocument?> findPendingCreation(String requestId) async => null;
  Future<void> applyRecoveryDocument(RouteDocument document) async {}

  bool _connectionFailure(Object error) =>
      error is SocketException ||
      error is HttpException ||
      error is TimeoutException ||
      (error is ApiException && error.statusCode >= 500);

  void _pauseConnection() {
    connectionInterrupted = true;
    _renewTimer?.cancel();
    notifyListeners();
  }

  Future<void> _checkConnection() async {
    if (_closed ||
        _closing ||
        documentBusy ||
        _checkingConnection ||
        lockRepository == null) {
      return;
    }
    if (connectionInterrupted) {
      await retryConnection();
      return;
    }
    if (!isEditing) return;
    final version = _sessionVersion;
    _checkingConnection = true;
    try {
      await lockRepository!.checkConnection();
    } catch (error) {
      if (version == _sessionVersion &&
          !_closed &&
          !_closing &&
          _connectionFailure(error)) {
        _pauseConnection();
      }
    } finally {
      _checkingConnection = false;
    }
  }

  void _startHeartbeat() {
    _renewTimer?.cancel();
    _renewTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => renewDocumentLock(),
    );
  }

  Future<bool> retryConnection() {
    if (_reconnectRequest != null) return _reconnectRequest!;
    final request = _retryConnection();
    _reconnectRequest = request;
    return request.whenComplete(() => _reconnectRequest = null);
  }

  Future<bool> _retryConnection() async {
    if (!connectionInterrupted || _closed || _closing || documentBusy) {
      return false;
    }
    final version = _sessionVersion;
    final id = documentId;
    reconnecting = true;
    notifyListeners();
    try {
      await lockRepository!.checkConnection();
      if (version != _sessionVersion || _closed || _closing) return false;
      if (id == null) {
        final created = _saveUnconfirmed && _pendingOperationId != null
            ? await findPendingCreation(_pendingOperationId!)
            : null;
        if (version != _sessionVersion || _closed || _closing) return false;
        if (created != null) {
          await applyRecoveryDocument(created);
          isEditing = false;
          _draftStarted = false;
          documentChanged = true;
          documentError = 'Сервер подтвердил сохранение документа. Показаны сохранённые данные.';
          _saveUnconfirmed = false;
          _pendingOperationId = null;
        }
        connectionInterrupted = false;
        return true;
      }
      try {
        final owner = await lockRepository!.acquireEditLock(id);
        if (version != _sessionVersion || _closed || _closing) {
          await _releaseQuietly(id);
          return false;
        }
        lockOwner = owner;
        _hasLock = true;
      } on ApiException catch (error) {
        if (!{403, 409, 423}.contains(error.statusCode)) rethrow;
        _hasLock = false;
        _discardReason = error.statusCode == 423
            ? 'Редактирование прекращено: документ редактирует ${error.ownerName ?? 'другой сотрудник'}. Несохранённые изменения отменены.'
            : 'Редактирование прекращено: документ больше недоступен для изменений. Показаны сохранённые данные.';
      }
      if (version != _sessionVersion || _closed || _closing) return false;
      final current = await readRecoveryDocument();
      if (version != _sessionVersion || _closed || _closing) return false;
      final saved =
          _saveUnconfirmed &&
          current != null &&
          current.lastOperationId == _pendingOperationId;
      final changed =
          current != null &&
          (current.revision != documentRevision || !current.isActive);
      if (_discardReason != null || changed || saved) {
        if (current != null) {
          await applyRecoveryDocument(current);
        } else {
          await refreshForEditing();
        }
        if (_hasLock) {
          try {
            await lockRepository!.releaseEditLock(id);
          } on ApiException catch (error) {
            if (!{403, 409}.contains(error.statusCode)) rethrow;
          }
        }
        _hasLock = false;
        _draftStarted = false;
        isEditing = false;
        documentError =
            _discardReason ??
            (saved
                ? 'Сервер подтвердил сохранение документа. Показаны сохранённые данные.'
                : 'Документ изменился за время отсутствия связи. Несохранённые изменения отменены. Показаны актуальные данные.');
        documentChanged = true;
        _discardReason = null;
        _pendingOperationId = null;
        _saveUnconfirmed = false;
      } else {
        _startHeartbeat();
        documentError = null;
      }
      connectionInterrupted = false;
      return true;
    } catch (error) {
      if (version == _sessionVersion && !_closed) {
        if (error is ApiException &&
            error.statusCode == 404 &&
            documentId != null) {
          points = [];
          isEditing = false;
          _draftStarted = false;
          _hasLock = false;
          connectionInterrupted = false;
          documentError =
              'Документ больше не найден. Редактирование прекращено.';
        }
      }
      return false;
    } finally {
      if (version == _sessionVersion) {
        reconnecting = false;
        notifyListeners();
      }
    }
  }

  Future<bool> beginEditing() {
    if (_acquireRequest != null) {
      return _acquireRequest!;
    }
    final request = _beginEditing();
    _acquireRequest = request;
    return request.whenComplete(() => _acquireRequest = null);
  }

  Future<bool> _beginEditing() async {
    if (connectionInterrupted) return retryConnection();
    final id = documentId;
    final version = _sessionVersion;
    if (id == null || !documentActive || documentBusy || _closed || _closing) {
      return false;
    }
    documentBusy = true;
    documentError = null;
    notifyListeners();
    try {
      lockOwner = await lockRepository!.acquireEditLock(id);
      _hasLock = true;
      if (version != _sessionVersion || _closed || _closing) {
        await lockRepository!.releaseEditLock(id);
        _hasLock = false;
        return false;
      }
      if (!_draftStarted) await refreshForEditing();
      if (version != _sessionVersion || _closed || _closing) {
        await lockRepository!.releaseEditLock(id);
        _hasLock = false;
        return false;
      }
      isEditing = true;
      _draftStarted = true;
      _startHeartbeat();
      return true;
    } catch (error) {
      isEditing = false;
      documentError = documentFailure(error);
      return false;
    } finally {
      documentBusy = false;
      notifyListeners();
    }
  }

  Future<void> renewDocumentLock() {
    if (_renewRequest != null) {
      return _renewRequest!;
    }
    final request = _renewDocumentLock();
    _renewRequest = request;
    return request.whenComplete(() => _renewRequest = null);
  }

  Future<void> _renewDocumentLock() async {
    final id = documentId;
    final version = _sessionVersion;
    if (id == null ||
        !isEditing ||
        connectionInterrupted ||
        _closed ||
        _closing ||
        documentBusy) {
      return;
    }
    try {
      final owner = await lockRepository!.renewEditLock(id);
      if (version == _sessionVersion && !_closed && !_closing) {
        lockOwner = owner;
      }
    } catch (error) {
      if (version != _sessionVersion || _closed || _closing) return;
      if (_connectionFailure(error) ||
          (error is ApiException &&
              {403, 409, 423}.contains(error.statusCode))) {
        if (error is ApiException && error.statusCode == 423) {
          _discardReason =
              'Редактирование прекращено: документ редактирует ${error.ownerName ?? 'другой сотрудник'}. Несохранённые изменения отменены.';
        }
        _pauseConnection();
      } else {
        documentError = documentFailure(error);
      }
      notifyListeners();
    }
  }

  Future<bool> cancelEditing() async {
    if (documentId == null ||
        !isEditing ||
        documentBusy ||
        _closed ||
        _closing) {
      return false;
    }
    documentBusy = true;
    documentError = null;
    notifyListeners();
    try {
      // Finish any heartbeat before reloading and releasing the same lock.
      await _renewRequest;
      await refreshForEditing();
      if (_hasLock) {
        try {
          await lockRepository!.releaseEditLock(documentId!);
        } catch (error) {
          if (error is! ApiException ||
              !{403, 409}.contains(error.statusCode)) {
            rethrow;
          }
        }
      }
      _renewTimer?.cancel();
      _sessionVersion++;
      _hasLock = false;
      _draftStarted = false;
      isEditing = false;
      lockOwner = null;
      documentError = null;
      return true;
    } catch (error) {
      if (_connectionFailure(error)) {
        _discardReason = 'Редактирование отменено. Показаны сохранённые данные.';
        _pauseConnection();
      }
      documentError =
          'Не удалось отменить редактирование. Повторите попытку. ${documentFailure(error)}';
      return false;
    } finally {
      documentBusy = false;
      notifyListeners();
    }
  }

  Future<bool> closeDocument() async {
    if (connectionInterrupted) return false;
    if (_closed) {
      return true;
    }
    if (_closing) {
      return false;
    }
    _closing = true;
    _renewTimer?.cancel();
    notifyListeners();
    await _acquireRequest;
    await _renewRequest;
    _renewTimer?.cancel();
    try {
      if (documentId != null && _hasLock) {
        await lockRepository!.releaseEditLock(documentId!);
      }
    } catch (error) {
      if (error is! ApiException || !{403, 409}.contains(error.statusCode)) {
        documentError =
            'Не удалось освободить блокировку. Повторите закрытие. ${documentFailure(error)}';
        _closing = false;
        if (_connectionFailure(error)) {
          _pauseConnection();
        } else {
          isEditing = false;
        }
        notifyListeners();
        return false;
      }
    }
    _sessionVersion++;
    _closed = true;
    _connectionTimer?.cancel();
    _hasLock = false;
    _closing = false;
    isEditing = false;
    notifyListeners();
    return true;
  }

  void handleDocumentError(Object error) {
    if (_connectionFailure(error) && isEditing) {
      _pauseConnection();
      return;
    }
    if (error is ApiException &&
        {403, 409, 423}.contains(error.statusCode) &&
        isEditing) {
      if (error.data['code'] == 'document_revision_conflict') {
        _discardReason = 'Документ изменён другим сотрудником. Несохранённые изменения отменены.';
      }
      _pauseConnection();
      return;
    }
    _saveUnconfirmed = false;
    _pendingOperationId = null;
    documentError = documentFailure(error);
    if (error is ApiException && {403, 409, 423}.contains(error.statusCode)) {
      isEditing = false;
      _renewTimer?.cancel();
      lockOwner = error.ownerName;
    }
  }

  String documentFailure(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 423) {
        return 'Документ редактирует: ${error.ownerName ?? 'другой сотрудник'}.';
      }
      if (error.statusCode == 409) {
        return 'Блокировка отсутствует или документ отменён. Обновите документ или начните редактирование повторно.';
      }
      if (error.statusCode == 422) {
        return 'Данные не приняты сервером. Проверьте поля и активность выбранных записей.';
      }
      if (error.statusCode == 404) {
        return 'Документ или связанная запись не найдены.';
      }
    }
    return 'Не удалось выполнить запрос. Проверьте соединение и повторите попытку.';
  }

  @override
  void dispose() {
    if (_hasLock && documentId != null) unawaited(_releaseQuietly(documentId!));
    _connectionTimer?.cancel();
    _renewTimer?.cancel();
    _closed = true;
    _sessionVersion++;
    super.dispose();
  }

  Future<void> _releaseQuietly(String id) async {
    try {
      await lockRepository?.releaseEditLock(id);
    } catch (_) {
      // Server ownership checks prevent releasing another employee's lock.
      // If offline, the lease expires without extending it.
    }
  }

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
        pointId: point.pointId,
        position: point.position,
        salesRepresentativeId: point.salesRepresentativeId,
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
    if (!method.isActive) {
      return false;
    }
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

  Future<bool> selectPointRepresentative(
    String clientId,
    ClientDirectoryEntry representative,
    ClientsProvider clientsProvider,
  ) async {
    if (!canEdit || !representative.isActive) return false;
    final client = await clientRepo.updateClient(
      clientId,
      UpdateClientRequest(salesRepresentativeId: representative.id),
    );
    clientsProvider.syncUpdatedClient(client);
    final index = points.indexWhere((point) => point.clientId == clientId);
    if (index != -1) {
      final point = points[index];
      points[index] = RoutePoint(
        pointId: point.pointId,
        position: point.position,
        clientId: point.clientId,
        clientName: point.clientName,
        city: point.city,
        address: point.address,
        phone: point.phone,
        paymentMethodId: point.paymentMethodId,
        paymentMethod: point.paymentMethod,
        salesRepresentativeId: client.salesRepresentativeId,
        salesRepresentative:
            client.salesRepresentativeName ?? 'Нет представителя',
        items: point.items,
      );
    }
    notifyListeners();
    return true;
  }

  double get grandTotal =>
      points.fold(0, (sum, point) => sum + point.totalCents) / 100;

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

  void syncClientPoint(Client client) {
    points = points
        .map(
          (point) => point.clientId != client.id
              ? point
              : RoutePoint(
                  pointId: point.pointId,
                  position: point.position,
                  salesRepresentativeId: client.salesRepresentativeId,
                  clientId: point.clientId,
                  clientName: client.name,
                  city: point.city,
                  address: [
                    client.address,
                    if (client.deliveryDetails.isNotEmpty)
                      client.deliveryDetails,
                  ].join(' — '),
                  phone: client.phone,
                  paymentMethodId: client.defaultPaymentMethodId,
                  paymentMethod: client.defaultPaymentMethodName,
                  salesRepresentative:
                      client.salesRepresentativeName ?? 'Нет представителя',
                  items: point.items,
                ),
        )
        .toList();
    notifyListeners();
  }

  void addClientPoint(Client client) {
    if (!canEdit) return;
    if (!client.isActive || points.any((p) => p.clientId == client.id)) {
      return;
    }

    points.add(
      RoutePoint(
        clientId: client.id,
        clientName: client.name,
        city: '',
        salesRepresentativeId: client.salesRepresentativeId,
        address: [
          client.address,
          if (client.deliveryDetails.isNotEmpty) client.deliveryDetails,
        ].join(' — '),
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
    if (!canEdit) return;
    points.removeAt(index);
    notifyListeners();
  }

  void reorderPoints(int oldIndex, int newIndex) {
    if (!canEdit) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final point = points.removeAt(oldIndex);
    points.insert(newIndex, point);

    notifyListeners();
  }

  void addTaskToPoint(
    int pointIndex,
    Product product,
    int quantity, {
    String? productName,
  }) {
    if (!canEdit) return;
    if (!product.isActive || quantity <= 0) return;
    final currentPoint = points[pointIndex];

    final updatedItems = List<DeliveryTaskItem>.from(currentPoint.items);

    final existingIndex = updatedItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) return;
    updatedItems.add(
      DeliveryTaskItem(
        productId: product.id,
        productName: productName ?? product.name,
        quantity: quantity,
        price: product.basePrice,
      ),
    );

    points[pointIndex] = RoutePoint(
      pointId: currentPoint.pointId,
      position: currentPoint.position,
      salesRepresentativeId: currentPoint.salesRepresentativeId,
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
    if (!canEdit) return;
    final point = points[pointIndex];
    final items = List<DeliveryTaskItem>.from(point.items)..removeAt(taskIndex);
    points[pointIndex] = point.copyWith(items: items);
    notifyListeners();
  }

  void updateTaskQuantity(
    int pointIndex,
    int taskIndex,
    int quantity,
  ) {
    if (!canEdit || pointIndex < 0 || pointIndex >= points.length) return;
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
      pointId: currentPoint.pointId,
      position: currentPoint.position,
      salesRepresentativeId: currentPoint.salesRepresentativeId,
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

  Future<bool> addCurrentProduct(
    int pointIndex,
    String productId,
    int quantity, {
    required String productName,
  }) async {
    if (!canEdit) {
      return false;
    }
    final point = points[pointIndex];
    if (point.items.any((item) => item.productId == productId)) {
      documentError =
          'Этот товар уже добавлен. Измените количество существующей строки.';
      notifyListeners();
      return false;
    }
    try {
      final product = await productRepo.getProductById(productId);
      if (!canEdit || !product.isActive) {
        documentError = 'Нельзя добавить неактивный товар.';
        notifyListeners();
        return false;
      }
      final index = points.indexOf(point);
      if (index < 0) {
        return false;
      }
      addTaskToPoint(index, product, quantity, productName: productName);
      return true;
    } catch (error) {
      documentError = documentFailure(error);
      notifyListeners();
      return false;
    }
  }

  Future<Product> currentCatalogProduct(String id) =>
      productRepo.getProductById(id);
  bool replaceItemPrice(
    RoutePoint point,
    DeliveryTaskItem item,
    Product product,
  ) {
    if (!canEdit || !product.isActive || product.id != item.productId) {
      return false;
    }
    final index = points.indexOf(point);
    if (index < 0) {
      return false;
    }
    final itemIndex = point.items.indexOf(item);
    if (itemIndex < 0) {
      return false;
    }
    final items = List<DeliveryTaskItem>.from(point.items);
    items[itemIndex] = DeliveryTaskItem(
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      price: product.basePrice,
    );
    points[index] = point.copyWith(items: items);
    notifyListeners();
    return true;
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
    String? name,
    double? basePrice,
  }) async {
    final normalizedName = name?.trim();

    if ((normalizedName != null && normalizedName.isEmpty) ||
        (basePrice != null && basePrice < 0)) {
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
    if (cleanName.isEmpty) {
      return null;
    }
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
