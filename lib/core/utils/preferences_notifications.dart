import 'package:shared_preferences/shared_preferences.dart';

/// Ce que le lecteur accepte de recevoir.
///
/// Les interrupteurs de l'écran « Notifications » écrivaient bien leur état sur
/// l'appareil, et le relisaient à l'ouverture — mais personne d'autre ne les
/// consultait. Le fournisseur de notifications appelait
/// `showLocalNotification` sans condition : couper « Rappels de lecture »
/// n'empêchait aucun rappel d'arriver. L'interrupteur ne mémorisait que sa
/// propre position.
///
/// Cette classe est le seul endroit qui traduit un type de notification en
/// préférence, pour que l'écran de réglage et le moment de l'affichage ne
/// puissent pas diverger.
class PreferencesNotifications {
  PreferencesNotifications._();

  /// Rappels d'inactivité — « vous n'avez pas lu depuis trois jours ».
  static const String cleRappelsLecture = 'pref_readingReminders';

  /// Vie de la communauté : avis reçus, messages dans un salon, nouvelle
  /// publication d'un auteur suivi.
  static const String cleCommunaute = 'pref_newComments';

  /// Ventes, pour un auteur.
  static const String cleVentes = 'pref_salesReminders';

  /// Les types réellement émis par le serveur, relevés dans les appels à
  /// `CreateNotification` :
  ///
  ///   communaute      avis, salon, message, nouvel événement, nouveau livre
  ///   rappel_lecture  relance après inactivité
  ///   vente           un livre de l'auteur a été acheté
  ///   achat           le paiement du lecteur est validé
  ///
  /// `achat` n'est volontairement pas gouverné par un interrupteur : c'est la
  /// confirmation d'un paiement. Un utilisateur qui a payé doit être prévenu,
  /// même s'il a tout coupé par ailleurs — le taire serait un défaut, pas un
  /// respect de sa préférence.
  static const Map<String, String> _cleParType = {
    'rappel_lecture': cleRappelsLecture,
    'communaute': cleCommunaute,
    'vente': cleVentes,
  };

  /// Faut-il afficher une alerte système pour ce type ?
  ///
  /// Un type inconnu s'affiche. Le silence par défaut ferait disparaître toute
  /// notification nouvelle jusqu'à ce que quelqu'un pense à l'ajouter ici, et
  /// personne ne s'apercevrait de rien.
  static Future<bool> doitAfficher(String type) async {
    final cle = _cleParType[type.trim().toLowerCase()];
    if (cle == null) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      // Absent = jamais réglé = accepté. On n'impose pas le silence à qui n'a
      // rien demandé.
      return prefs.getBool(cle) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Lit une préférence, pour l'écran de réglage.
  static Future<bool> lire(String cle, {bool defaut = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(cle) ?? defaut;
    } catch (_) {
      return defaut;
    }
  }

  /// Enregistre une préférence.
  static Future<void> ecrire(String cle, bool valeur) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(cle, valeur);
    } catch (_) {}
  }
}
