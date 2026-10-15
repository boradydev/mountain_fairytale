import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';

import 'package:mountain_fairytale/features/commissions/data/commission_models.dart';
import 'package:mountain_fairytale/features/commissions/data/commissions_repo.dart';

enum CommissionMode { representatives, employees }

class CommissionsProvider extends SafeChangeNotifier {
  final CommissionsRepository repository;
  CommissionsProvider(this.repository);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  CommissionMode mode = CommissionMode.representatives;
  bool includeDeactivated = false;
  bool loading = false;
  String? error;
  CommissionReport? report;
  int _generation = 0;
  bool _disposed = false;

  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.report(
        month,
        includeDeactivated: includeDeactivated,
      );
      if (_disposed || generation != _generation) return;
      report = result;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = 'Не удалось загрузить начисления. Повторите запрос.';
    }
    if (_disposed || generation != _generation) return;
    loading = false;
    notifyListeners();
  }

  Future<void> setMonth(DateTime value) {
    month = DateTime(value.year, value.month);
    report = null;
    return refresh();
  }

  Future<void> setIncludeDeactivated(bool value) {
    includeDeactivated = value;
    return refresh();
  }

  void setMode(CommissionMode value) {
    mode = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
