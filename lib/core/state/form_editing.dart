import 'dart:async';

/// Compares values after each form has normalized its own fields.
Map<String, Object?> changedFormFields(
  Map<String, Object?> original,
  Map<String, Object?> current,
) => Map.fromEntries(
  current.entries.where((entry) => original[entry.key] != entry.value),
);

double? formNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Debounces input, shares the current request with Save and cancels stale timers.
class DuplicateCheckCoordinator {
  DuplicateCheckCoordinator(this._input);
  String _input;
  Timer? _timer;
  int _generation = 0;
  int? _pendingGeneration;
  String? _pendingInput;
  Future<bool>? _pending;
  bool _disposed = false;

  bool inputChanged(
    String input, {
    required bool canCheck,
    required Future<bool> Function() check,
  }) {
    if (_disposed || input == _input) return false;
    _input = input;
    _generation++;
    _timer?.cancel();
    if (canCheck) {
      _timer = Timer(const Duration(milliseconds: 600), () {
        unawaited(check());
      });
    }
    return true;
  }

  Future<bool> run(String input, Future<bool> Function() check) {
    _timer?.cancel();
    if (_disposed) return Future.value(false);
    if (_pendingInput == input &&
        _pendingGeneration == _generation &&
        _pending != null) {
      return _pending!;
    }
    final generation = _generation;
    final pending = Future<bool>.sync(check);
    _pending = pending;
    _pendingInput = input;
    _pendingGeneration = generation;
    return pending.whenComplete(() {
      if (identical(_pending, pending)) _pending = null;
    });
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
  }
}
