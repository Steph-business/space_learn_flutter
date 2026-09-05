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
///
/// RÉGLAGES D'APPAREIL, PAS DE COMPTE — décision prise, à ne pas défaire par
/// mégarde. Ces trois clés n'ont volontairement AUCUN suffixe d'identifiant,
/// contrairement à presque toutes les autres données locales du dépôt. Elles
/// vivent avec le thème, la langue et la voix de synthèse : ce qu'on règle une
/// fois pour ce téléphone.
///
/// Les rattacher au compte serait défendable — deux personnes qui se partagent
/// un appareil ne veulent pas forcément le même silence. Mais le passage
/// coûterait plus qu'il ne rapporterait : les clés sans suffixe déjà posées sur
/// les appareils installés deviendraient illisibles, et `doitAfficher` retombe
/// alors sur son défaut « accepté ». Autrement dit, au premier lancement suivant
/// la mise à jour, quiconque avait tout coupé recommencerait à recevoir des
/// notifications sans avoir rien demandé, et sans savoir pourquoi. Faire du
/// bruit chez qui a demandé le silence est un tort plus grave que celui qu'on
/// corrigerait.
///
/// Aucune purge dans `SessionService.terminer`, donc, pour la même raison : la
/// déconnexion ne doit pas rallumer des alertes que l'utilisateur avait
/// éteintes. Un réglage d'appareil ne quitte pas l'appareil.
///
/// Ce qui rendrait la décision réversible sans ce tort : lire l'ancienne clé
/// sans suffixe comme valeur initiale de la clé suffixée, une seule fois, à la
/// première lecture du compte.
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
  ///   communaute      salon, message, nouvel événement, nouveau livre
  ///   avis            un avis a été déposé sur votre livre
  ///   nouvel_abonne   quelqu'un s'est abonné à vous
  ///   rappel_lecture  relance après inactivité
  ///   vente           un livre de l'auteur a été acheté
  ///   achat           le paiement du lecteur est validé
  ///
  /// `achat` n'est volontairement pas gouverné par un interrupteur : c'est la
  /// confirmation d'un paiement. Un utilisateur qui a payé doit être prévenu,
  /// même s'il a tout coupé par ailleurs — le taire serait un défaut, pas un
  /// respect de sa préférence.
  ///
  /// `avis` et `nouvel_abonne` sont sortis de `communaute` côté serveur pour
  /// pouvoir mener quelque part de précis. Ils restent gouvernés par le MÊME
  /// interrupteur : sans ces deux lignes, qui avait coupé « Vie de la
  /// communauté » recevrait de nouveau les avis et les abonnements, sans avoir
  /// rien changé à son réglage.
  static const Map<String, String> _cleParType = {
    'rappel_lecture': cleRappelsLecture,
    'communaute': cleCommunaute,
    'avis': cleCommunaute,
    'nouvel_abonne': cleCommunaute,
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
