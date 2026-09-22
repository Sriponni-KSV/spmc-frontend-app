import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'spmc_language_code';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isTamil => _locale.languageCode == 'ta';

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ta'),
  ];

  String get currentLanguageName {
    switch (_locale.languageCode) {
      case 'ta':
        return 'தமிழ்';
      case 'en':
      default:
        return 'English';
    }
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null && (savedCode == 'en' || savedCode == 'ta')) {
        _locale = Locale(savedCode);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error initializing LanguageProvider: $e');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    if (newLocale.languageCode != 'en' && newLocale.languageCode != 'ta') return;

    _locale = newLocale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newLocale.languageCode);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  Future<void> setLanguageCode(String code) async {
    await setLocale(Locale(code));
  }

  Future<void> toggleLanguage() async {
    if (isTamil) {
      await setLocale(const Locale('en'));
    } else {
      await setLocale(const Locale('ta'));
    }
  }
}
