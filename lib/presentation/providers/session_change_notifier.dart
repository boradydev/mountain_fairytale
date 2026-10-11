import 'package:flutter/foundation.dart';

/// A removed session may still have in-flight repository requests.
class SessionChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
