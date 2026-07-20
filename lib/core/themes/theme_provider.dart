import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = "app_theme_mode";
  ThemeMode _themeMode = ThemeMode.dark; // Par défaut, thème sombre

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey) ?? "dark";
    if (themeStr == "light") {
      _themeMode = ThemeMode.light;
    } else if (themeStr == "dark") {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    AppColors.isDark = isDarkMode;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String themeStr = "dark";
    if (mode == ThemeMode.light) {
      themeStr = "light";
    } else if (mode == ThemeMode.system) {
      themeStr = "system";
    }
    await prefs.setString(_themeKey, themeStr);
    AppColors.isDark = isDarkMode;
    notifyListeners();
  }
}