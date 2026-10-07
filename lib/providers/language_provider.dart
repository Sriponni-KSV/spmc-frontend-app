import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/auth_controller.dart';

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

  /// Initialize language state.
  /// If a valid user is provided, sets to that user's preferred language from DB.
  /// If no user or user has no Tamil preference, defaults strictly to English ('en').
  Future<void> initialize({String? userPreferredLanguage, int? userId}) async {
    try {
      if (userId != null && userPreferredLanguage != null) {
        final targetCode = (userPreferredLanguage.trim().toLowerCase() == 'ta') ? 'ta' : 'en';
        _locale = Locale(targetCode);
        notifyListeners();
        return;
      }
      // When no user is authenticated, default strictly to English
      _locale = const Locale('en');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing LanguageProvider: $e');
    }
  }

  /// Syncs language strictly for the currently logged-in user.
  /// If preferredLanguage from DB is 'ta', sets to Tamil.
  /// For any other user / value, sets to English ('en').
  Future<void> syncFromUserDb(String? preferredLanguage, {int? userId}) async {
    final targetCode = (preferredLanguage?.trim().toLowerCase() == 'ta') ? 'ta' : 'en';
    if (_locale.languageCode != targetCode) {
      _locale = Locale(targetCode);
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        await prefs.setString('${_prefKey}_$userId', targetCode);
      }
      await prefs.setString(_prefKey, targetCode);
    } catch (_) {}
  }

  /// Resets language strictly back to English default (e.g. on logout or on login page).
  Future<void> resetToDefault() async {
    if (_locale.languageCode != 'en') {
      _locale = const Locale('en');
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, 'en');
    } catch (_) {}
  }

  Future<void> setLocale(Locale newLocale, {bool syncWithBackend = true, int? userId}) async {
    if (newLocale.languageCode != 'en' && newLocale.languageCode != 'ta') return;

    final targetCode = newLocale.languageCode;
    if (_locale.languageCode != targetCode) {
      _locale = newLocale;
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        await prefs.setString('${_prefKey}_$userId', targetCode);
      }
      await prefs.setString(_prefKey, targetCode);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }

    if (syncWithBackend) {
      try {
        await AuthController().updatePreferredLanguage(targetCode);
      } catch (e) {
        debugPrint('Error syncing language with backend: $e');
      }
    }
  }

  Future<void> setLanguageCode(String code, {bool syncWithBackend = true, int? userId}) async {
    await setLocale(Locale(code), syncWithBackend: syncWithBackend, userId: userId);
  }

  Future<void> toggleLanguage({int? userId}) async {
    if (isTamil) {
      await setLocale(const Locale('en'), userId: userId);
    } else {
      await setLocale(const Locale('ta'), userId: userId);
    }
  }
}
