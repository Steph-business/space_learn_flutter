import 'package:shared_preferences/shared_preferences.dart';

/// Service gérant l'état des guides interactifs (onboarding / coach marks)
/// de l'application selon les standards des grandes plateformes.
class OnboardingGuideService {
  static const String _homeTourKey = 'has_seen_home_guide_v1';
  static const String _readerTourKey = 'has_seen_reader_guide_v1';
  static const String _marketplaceTourKey = 'has_seen_marketplace_guide_v1';

  /// Vérifie si le guide d'accueil doit être présenté (1ère visite)
  static Future<bool> shouldShowHomeTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_homeTourKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Marque le guide de l'accueil comme terminé
  static Future<void> markHomeTourCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_homeTourKey, true);
    } catch (_) {}
  }

  /// Réinitialise l'état du guide d'accueil pour le rejouer
  static Future<void> resetHomeTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homeTourKey);
    } catch (_) {}
  }

  /// Réinitialise tous les guides de l'application
  static Future<void> resetAllTours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homeTourKey);
      await prefs.remove(_readerTourKey);
      await prefs.remove(_marketplaceTourKey);
    } catch (_) {}
  }
}
