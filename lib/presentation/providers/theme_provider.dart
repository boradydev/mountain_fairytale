import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mountain_fairytale/core/theme.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  ThemeMode _themeMode;

  ThemeProvider(this.prefs) : _themeMode = ThemeMode.light {
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeData get lightTheme => AppTheme.createTheme(Brightness.light);

  ThemeData get darkTheme => AppTheme.createTheme(Brightness.dark);

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    prefs.setBool('is_dark_mode', isDarkMode);
    notifyListeners();
  }
}
