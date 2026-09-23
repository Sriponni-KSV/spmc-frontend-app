import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'spmc_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool isDarkMode(BuildContext context) {
    return _themeMode == ThemeMode.dark;
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_prefKey);
      if (savedMode != null && savedMode == 'dark') {
        // As requested by user, reset theme to white (light) as previous
        _themeMode = ThemeMode.light;
        await prefs.setString(_prefKey, 'light');
      } else {
        _themeMode = ThemeMode.light;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing ThemeProvider: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr = 'system';
      if (mode == ThemeMode.light) modeStr = 'light';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      await prefs.setString(_prefKey, modeStr);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
