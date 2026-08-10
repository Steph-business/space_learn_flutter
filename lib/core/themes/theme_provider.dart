import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = "app_theme_mode";

  /// Thème par défaut de l'application : clair.
  static const ThemeMode defaultThemeMode = ThemeMode.light;

  ThemeMode _themeMode = defaultThemeMode;

  ThemeMode get themeMode => _themeMode;

  /// Construit un provider déjà positionné sur le mode voulu.
  /// Utilisé avec [loadSavedMode] pour éviter que la première frame soit
  /// rendue dans la mauvaise palette le temps que les préférences se chargent.
  ThemeProvider({ThemeMode? initialMode}) {
    _themeMode = initialMode ?? defaultThemeMode;
    AppColors.isDark = isDarkMode;
    if (initialMode == null) {
      _loadTheme();
    }
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Lit le mode enregistré. À appeler dans `main()` avant `runApp`.
  static Future<ThemeMode> loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_themeKey));
  }

  static ThemeMode _parse(String? value) {
    switch (value) {
      case "light":
        return ThemeMode.light;
      case "dark":
        return ThemeMode.dark;
      case "system":
        return ThemeMode.system;
      default:
        return defaultThemeMode;
    }
  }

  static String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return "light";
      case ThemeMode.dark:
        return "dark";
      case ThemeMode.system:
        return "system";
    }
  }

  Future<void> _loadTheme() async {
    _themeMode = _parse((await SharedPreferences.getInstance()).getString(_themeKey));
    AppColors.isDark = isDarkMode;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    // La palette globale est mise à jour AVANT de notifier, pour que la
    // reconstruction déclenchée par notifyListeners lise déjà les bonnes
    // couleurs. L'écriture en préférences vient après : elle est asynchrone et
    // ne doit pas retarder l'affichage.
    AppColors.isDark = isDarkMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _serialize(mode));
  }
}
