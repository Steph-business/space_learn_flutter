import 'package:flutter/foundation.dart';

import 'book_cache_service.dart';
import 'lecture_audio_livre.dart';
import 'rappel_evenement.dart';
import 'rappels_lecture.dart';
import 'tts_service.dart';
import '../space_learn/data/dataServices/badgeService.dart';
import '../space_learn/data/dataServices/reading_time_storage.dart';
import '../space_learn/pages/principales/ecrivain/ajouter_livre_page.dart';
import '../utils/profile_storage.dart';
import '../utils/token_storage.dart';

/// Fin de session.
///
/// Point unique de nettoyage : jeton, profil sélectionné et livres téléchargés.
/// Les trois chemins de déconnexion effaçaient auparavant le seul jeton, ce qui
/// laissait sur l'appareil la bibliothèque complète de l'utilisateur — lisible
/// hors ligne par la personne suivante à s'y connecter, ou par l'acheteur d'un
/// téléphone d'occasion.
class SessionService {
  /// Purges d'état EN MÉMOIRE, enregistrées par les objets qui survivent à la
  /// navigation.
  ///
  /// NotificationProvider est créé à la racine de l'application et vit plus
  /// longtemps que la session : sans purge, les notifications du compte
  /// déconnecté — ventes, messages privés, échecs de paiement — restaient en
  /// mémoire et s'affichaient au compte suivant sur le même téléphone.
  /// SessionService n'a pas de BuildContext pour les atteindre par Provider :
  /// ce sont donc eux qui s'inscrivent ici à leur création.
  ///
  /// La clé identifie L'INSCRIT, pas la sorte de données : le mieux est de
  /// passer `this`. Indexer par une chaîne constante ('notifications') marche
  /// tant qu'il n'existe qu'une instance, et se retourne dès qu'il y en a
  /// deux — un provider imbriqué, un test de widget, un rechargement à chaud
  /// partiel : la seconde inscription écrase la première, puis la première à
  /// mourir désinscrit la purge de la seconde, qui survit alors à la
  /// déconnexion avec les données du compte précédent.
  static final Map<Object, void Function()> _purgesMemoire = {};

  static void enregistrerPurge(Object cle, void Function() purge) {
    _purgesMemoire[cle] = purge;
  }

  /// Désinscrit une purge — la SIENNE seulement.
  ///
  /// Passer [purge] fait la différence entre « je m'en vais » et « j'efface
  /// l'inscription de quelqu'un d'autre » : si la valeur enregistrée sous
  /// cette clé n'est plus celle-ci, une autre instance a pris la place et son
  /// inscription doit rester. (Comparaison par `==` et non `identical` : deux
  /// références à la même méthode d'un même objet sont égales, pas forcément
  /// identiques.)
  static void oublierPurge(Object cle, [void Function()? purge]) {
    if (purge != null && _purgesMemoire[cle] != purge) return;
    _purgesMemoire.remove(cle);
  }

  /// Efface toute trace locale de la session.
  ///
  /// Chaque étape est indépendante : l'échec de l'une ne doit pas empêcher les
  /// autres. Une déconnexion qui laisse des données derrière elle est pire
  /// qu'une déconnexion partiellement en erreur.
  static Future<void> terminer() async {
    // LA VOIX SE TAIT D'ABORD, avant que le jeton ne disparaisse.
    //
    // La lecture audio est un singleton qui survit à la navigation : aucun
    // chemin de déconnexion ne l'arrêtait, et la voix continuait de lire le
    // livre du compte précédent par-dessus l'écran de connexion, jusqu'au
    // battement suivant. L'ordre reste le bon — `arreter()` tente de porter au
    // compte les minutes écoutées, donc tant que le jeton et le profil sont
    // encore là ; effacer d'abord les aurait tentées sans identité.
    //
    // RÉSERVE, à ne pas croire garantie : `arreter()` lance ce report sans
    // l'attendre (`unawaited` dans LectureAudioLivre._porterLeTemps), et le
    // report relit l'identifiant du compte APRÈS coup. Il court donc contre le
    // `clearToken` ci-dessous et perd, le plus souvent, les dernières minutes
    // de la séance. Le correctif tient dans lecture_audio_livre.dart (rendre
    // _porterLeTemps attendable, ou lui passer `_uidSeance` au lieu de relire
    // le stockage) ; tant qu'il n'est pas fait, ce commentaire dit ce que le
    // code fait, pas ce qu'on voudrait qu'il fasse.
    try {
      await LectureAudioLivre.instance.arreter();
    } catch (e) {
      debugPrint('SessionService: échec de l\'arrêt de la lecture audio — $e');
    }

    // Et la synthèse vocale elle-même, si c'est la page de lecture qui la
    // pilote : elle ne passe pas par LectureAudioLivre, et sa voix ne doit
    // pas non plus survivre à la déconnexion.
    try {
      await TtsService().stop();
    } catch (e) {
      debugPrint('SessionService: échec de l\'arrêt de la synthèse — $e');
    }

    for (final etape in <(String, Future<void> Function())>[
      ('jeton', TokenStorage.clearToken),
      ('profil', ProfileStorage.clearSelectedProfile),
      ('rôle', ProfileStorage.clearSelectedProfileRole),
      ('livres téléchargés', BookCacheService().clearAllCache),
      // Deux caches PAR COMPTE qui échappaient au nettoyage : le compte
      // suivant héritait des badges du précédent (écran Badges hors ligne,
      // statistiques de l'accueil) et de ses marqueurs « discussion vue le »
      // (pastilles de non-lus éteintes à tort sur le forum).
      ('badges', BadgeService.purgerCache),
      ('discussions vues', TokenStorage.clearDiscussionMarkers),
      // Le livre créé par une publication qui s'est arrêtée en chemin :
      // l'écran d'ajout le retient sous « publication_brouillon_<compte> »
      // pour le reprendre au lieu d'en créer un second. Sans cette étape,
      // l'auteur suivant sur le même téléphone se voyait proposer de
      // reprendre le brouillon du précédent — et le serveur refusait la mise
      // à jour d'un livre dont il n'est pas l'auteur, sur un écran incapable
      // d'expliquer pourquoi. Le balayage est fait par PRÉFIXE : il ne
      // dépend donc pas de l'identifiant du compte, que l'étape « jeton »
      // ci-dessus a déjà effacé, et l'ordre dans cette boucle est indifférent.
      ('brouillons de publication', AjouterLivrePage.purgerBrouillonsEnAttente),
      // L'adresse mémorisée pour pré-remplir l'écran de connexion : elle
      // appartient au compte qui part, pas à l'appareil. Sans cela le suivant
      // trouvait l'adresse du précédent dans le champ e-mail, et la
      // reconnexion silencieuse d'après changement de mot de passe pouvait
      // s'adresser au mauvais compte.
      ('e-mail mémorisé', ProfileStorage.clearSavedEmail),
      // Les rappels de rendez-vous : des notifications DÉJÀ PROGRAMMÉES dans
      // le système. Sans cette étape, le compte suivant voyait « Rappel posé »
      // sur des événements qu'il n'avait jamais notés et recevait, la veille
      // au soir, le rappel du compte précédent.
      //
      // On appelle la purge PUBLIQUE de RappelEvenement plutôt que de boucler
      // ici sur `poses()` + `retirer()`. Deux raisons, apparues quand ce
      // service a suffixé ses clés par l'identifiant du compte : `poses()` ne
      // lit que la clé du compte ENCORE connecté — or l'étape « jeton »
      // ci-dessus l'a déjà effacé, si bien que la boucle balayait une liste
      // vide et ne retirait plus rien ; et elle laissait intactes les listes
      // des autres comptes de l'appareil, ainsi que l'ancienne clé sans
      // suffixe, dont les notifications sonnent encore sans que personne
      // puisse les retirer. `purgerEtAnnuler` balaie tout le préfixe et
      // annule chaque notification programmée avant d'oublier sa liste.
      ('rappels de rendez-vous', RappelEvenement.purgerEtAnnuler),
      // Les rappels de LECTURE, jumeaux des précédents et oubliés jusqu'ici :
      // « rappels_lecture_<compte> » restait sur l'appareil, et surtout ses
      // notifications hebdomadaires étaient déjà déposées chez le système.
      // Le compte suivant recevait donc « C'est votre moment de lecture » le
      // mardi à 20 h 30 réglé par quelqu'un d'autre, sans pouvoir l'éteindre :
      // son écran « Temps de lecture » lit SA clé, et lui affichait une liste
      // vide. Même remarque que ci-dessus sur le balayage par préfixe, qui ne
      // dépend pas de l'identifiant déjà effacé par l'étape « jeton ».
      ('rappels de lecture', RappelsLecture.purgerEtAnnuler),
      // L'historique de lecture — LUI SEUL, et c'est le point à ne pas défaire.
      //
      // « reading_sessions_<compte> » garde les TITRES des livres lus et
      // l'heure de chaque séance : des cinq clés de ReadingTimeStorage, c'est
      // la seule NOMINATIVE, donc la seule qu'une personne peut avoir des
      // raisons de ne pas laisser derrière elle sur un téléphone. Elle part.
      //
      // Les COMPTEURS restent : temps cumulé, minutes du jour, secondes par
      // livre, objectif quotidien. Deux raisons, pesées ensemble.
      //   1. Ils ne trahissent personne. Tous sont suffixés par l'identifiant
      //      du compte, aucun ne porte de titre : le compte suivant sur cet
      //      appareil ne peut ni les lire ni en déduire quoi que ce soit.
      //   2. Les effacer coûterait au lecteur qui revient. Ce comptage local
      //      est le repli hors ligne de `ReaderStatsService.lireBilan` — les
      //      écrans s'en servent quand le serveur ne répond pas — et il
      //      contient aussi les minutes que le serveur n'a pas encore
      //      acceptées. Purgé à chaque déconnexion, un lecteur qui se
      //      reconnecte sans réseau verrait son temps cumulé et sa série de
      //      jours à zéro, sans avertissement et sans avoir rien perdu en
      //      réalité.
      // Même esprit que le solde de MinutesEnAttente, laissé lui aussi sur
      // l'appareil : ce qui appartient au compte et ne dit rien à personne
      // d'autre attend son retour plutôt que de disparaître.
      ('historique de lecture', ReadingTimeStorage.purgerSessions),
    ]) {
      try {
        await etape.$2();
      } catch (e) {
        debugPrint('SessionService: échec du nettoyage (${etape.$1}) — $e');
      }
    }

    // L'état en mémoire part avec le stockage, pour la même raison.
    for (final entree in _purgesMemoire.entries.toList()) {
      try {
        entree.value();
      } catch (e) {
        debugPrint(
          'SessionService: échec de la purge mémoire (${entree.key}) — $e',
        );
      }
    }
  }
}
