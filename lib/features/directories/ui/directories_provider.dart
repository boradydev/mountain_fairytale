import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/products/products_abcs.dart';
import 'package:mountain_fairytale/features/drivers/drivers_abcs.dart';
import 'package:mountain_fairytale/features/cars/cars_abcs.dart';
import 'package:mountain_fairytale/features/payment_methods/payment_method_abcs.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';

enum DirectorySection {
  products('Продукция', 'Добавить товар'),
  drivers('Водители', 'Добавить водителя'),
  cars('Автомобили', 'Добавить автомобиль'),
  paymentMethods('Способы оплаты', 'Добавить способ оплаты'),
  representatives('Торговые представители', 'Добавить представителя');

  const DirectorySection(this.label, this.addLabel);
  final String label;
  final String addLabel;
}

class DirectoryListState {
  List<Object> items = [];
  bool includeDeactivated = false;
  bool loading = false;
  String? error;
  int generation = 0;
}

class DirectoriesProvider extends SafeChangeNotifier {
  DirectoriesProvider({
    required this.products,
    required this.drivers,
    required this.cars,
    required this.paymentMethods,
    required this.representatives,
    required this.createEditor,
  });
  final ProductRepository products;
  final DriverRepository drivers;
  final CarRepository cars;
  final PaymentMethodRepository paymentMethods;
  final SalesRepresentativeApiRepository representatives;

  // Existing entity dialogs use a constructor provider. Each dialog receives
  // its own fresh instance, never the provider of a user's open document.
  final RouteConstructorProvider Function() createEditor;
  DirectorySection section = DirectorySection.products;
  final states = {
    for (final section in DirectorySection.values)
      section: DirectoryListState(),
  };
  DirectoryListState get current => states[section]!;
  bool _disposed = false;

  Future<void> selectSection(DirectorySection value) {
    section = value;
    notifyListeners();
    return refresh();
  }

  Future<void> setIncludeDeactivated(bool value) {
    current.includeDeactivated = value;
    return refresh();
  }

  Future<void> refresh([DirectorySection? target]) async {
    target ??= section;
    final state = states[target]!;
    final generation = ++state.generation;
    final include = state.includeDeactivated;
    state.loading = true;
    state.error = null;
    notifyListeners();
    try {
      final List<Object> rows = switch (target) {
        DirectorySection.products => await products.getAvailableProducts(
          includeDeactivated: include,
        ),
        DirectorySection.drivers => await drivers.getAvailableDrivers(
          includeDeactivated: include,
        ),
        DirectorySection.cars => await cars.getAvailableCars(
          includeDeactivated: include,
        ),
        DirectorySection.paymentMethods =>
          await paymentMethods.getAllPaymentMethods(
            includeDeactivated: include,
          ),
        DirectorySection.representatives => await representatives.getAll(
          includeDeactivated: include,
        ),
      };
      if (_disposed || generation != state.generation) return;
      state.items = rows;
    } catch (_) {
      if (_disposed || generation != state.generation) return;
      state.error = 'Не удалось загрузить справочник. Повторите запрос.';
    } finally {
      if (!_disposed && generation == state.generation) {
        state.loading = false;
        notifyListeners();
      }
    }
  }

  Future<Object> readCurrent(Object record) async => switch (record) {
    Product product => products.getProductById(product.id),
    Driver driver => drivers.getDriverById(driver.id),
    Car car => cars.getCarById(car.id),
    PaymentMethod method => paymentMethods.getPaymentMethodById(method.id),
    ApiSalesRepresentative representative => representatives.get(
      representative.id,
    ),
    _ => throw ArgumentError('Unsupported directory entry'),
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
