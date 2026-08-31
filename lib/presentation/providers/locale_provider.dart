import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  Locale _locale;

  LocaleProvider(this.prefs)
    : _locale = Locale(prefs.getString('language_code') ?? 'ru');

  Locale get locale => _locale;

  void toggleLocale() {
    final newCode = _locale.languageCode == 'ru' ? 'en' : 'ru';
    _locale = Locale(newCode);

    prefs.setString('language_code', newCode);
    notifyListeners();
  }
}
