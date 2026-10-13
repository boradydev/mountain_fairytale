import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/delivery_days/delivery_days_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';

class DayDocumentsProvider extends SafeChangeNotifier {
  final DeliveryDayRepository repository;
  final DateTime date;
  DayDocumentsProvider(this.repository, this.date);
  List<RouteDocument> documents = const [];
  bool includeCancelled = false;
  bool loading = false;
  String? error;
  int _version = 0;
  Future<void> setIncludeCancelled(bool value) {
    includeCancelled = value;
    return load();
  }

  Future<void> load() async {
    final version = ++_version;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.getDayDocuments(
        date,
        includeCancelled: includeCancelled,
      );
      if (version == _version) documents = result;
    } catch (_) {
      if (version == _version) {
        error = 'Не удалось загрузить документы дня. Повторите запрос.';
      }
    } finally {
      if (version == _version) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _version++;
    super.dispose();
  }
}
