import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_learn_flutter/core/utils/token_storage.dart';
import 'readerStatsService.dart';

/// Les minutes lues qui n'ont pas encore atteint le serveur.
///
/// La page de lecture les tenait dans un champ d'instance et les retranchait
/// AVANT de savoir si le serveur les avait acceptées :
///
///     _secondesEnAttenteServeur -= minutes * 60;
///     _statsService.recordReadingTime(bookId, minutes: minutes);
///     _statsService.declarerMinutes(minutes);
///
/// Deux pertes, donc. Lire dans le métro sans réseau n'atteignait jamais
/// `jours_de_lecture` — et avec elle tombaient le temps cumulé, la série de
/// jours et les cinq badges d'assiduité. Et le compteur mourait avec la page :
/// fermer un livre sur quarante secondes en attente les effaçait.
///
/// DEUX compteurs séparés, et c'est le point délicat. Les mêmes minutes partent
/// vers deux destinations — les statistiques PAR LIVRE de l'auteur, et le temps
/// PAR LECTEUR. Elles peuvent échouer indépendamment. Un compteur unique
/// obligerait à tout renvoyer dès que l'une des deux refuse, et renverrait donc
/// à l'autre des minutes qu'elle avait déjà comptées : c'est exactement ce qui
/// avait multiplié par quatre le temps de lecture affiché aux auteurs quand le
/// battement est passé de soixante à quinze secondes.
class MinutesEnAttente {
  MinutesEnAttente._();

  /// Secondes accumulées, pas encore converties en minutes entières.
  ///
  /// On n'envoie que des minutes pleines : déclarer « une minute » pour une
  /// session de quarante secondes gonflerait le total à chaque pause.
  static const String _cleSecondes = 'lecture_secondes_en_attente_';

  /// Minutes dues au compte du lecteur.
  static const String _cleLecteur = 'lecture_minutes_lecteur_';

  /// Minutes dues aux statistiques d'un livre. Suffixé par l'identifiant.
  static const String _cleLivre = 'lecture_minutes_livre_';

  /// Plafond d'un envoi, en minutes.
  ///
  /// Le serveur refuse au-delà : une séance de huit heures n'est pas crédible.
  /// Sans ce plafond côté client, un solde qui dépassait 480 était rejeté à
  /// CHAQUE tentative — il ne repartait donc jamais et grossissait
  /// indéfiniment. Le solde part maintenant par tranches, une par passage.
  static const int _maxMinutesParEnvoi = 480;

  /// Un seul envoi à la fois.
  ///
  /// Le battement de lecture tombe toutes les quinze secondes. Sans ce verrou,
  /// deux envois qui se chevauchent enverraient le même solde deux fois.
  static bool _envoiEnCours = false;

  static ReaderStatsService _service = ReaderStatsService();

  /// Point d'injection pour les tests. Rendre le service au repos ensuite.
  @visibleForTesting
  static set service(ReaderStatsService s) => _service = s;

  static Future<String?> _utilisateur() async {
    final id = await TokenStorage.getUserId();
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  /// Porte des secondes de lecture au crédit du lecteur et du livre.
  ///
  /// Rien n'est perdu si le serveur ne répond pas : le solde reste en attente
  /// et repartira à la prochaine occasion.
  static Future<void> porter({String? livreId, required int secondes}) async {
    if (secondes <= 0) return;

    final uid = await _utilisateur();
    if (uid == null) return; // pas de compte : rien à porter

    final prefs = await SharedPreferences.getInstance();

    final cleSecondes = '$_cleSecondes$uid';
    final cumul = (prefs.getInt(cleSecondes) ?? 0) + secondes;
    final minutes = cumul ~/ 60;
    await prefs.setInt(cleSecondes, cumul % 60);

    if (minutes > 0) {
      await _ajouter(prefs, '$_cleLecteur$uid', minutes);
      if (livreId != null && livreId.isNotEmpty) {
        await _ajouter(prefs, '$_cleLivre${uid}_$livreId', minutes);
      }
    }

    await vider();
  }

  static Future<void> _ajouter(
    SharedPreferences prefs,
    String cle,
    int minutes,
  ) async {
    await prefs.setInt(cle, (prefs.getInt(cle) ?? 0) + minutes);
  }

  /// Tente d'envoyer tout ce qui attend.
  ///
  /// À appeler aussi à l'ouverture d'un livre : c'est ce qui rattrape les
  /// minutes d'une session lue hors réseau.
  static Future<void> vider() async {
    if (_envoiEnCours) return;
    _envoiEnCours = true;
    try {
      final uid = await _utilisateur();
      if (uid == null) return;

      final prefs = await SharedPreferences.getInstance();
      await _viderLecteur(prefs, uid);
      await _viderLivres(prefs, uid);
    } catch (e) {
      debugPrint('Minutes en attente non envoyées : $e');
    } finally {
      _envoiEnCours = false;
    }
  }

  static Future<void> _viderLecteur(SharedPreferences prefs, String uid) async {
    final cle = '$_cleLecteur$uid';
    final solde = prefs.getInt(cle) ?? 0;
    if (solde <= 0) return;
    final du = solde > _maxMinutesParEnvoi ? _maxMinutesParEnvoi : solde;

    if (await _service.declarerMinutes(du)) {
      // On retranche ce qu'on a envoyé, pas le solde courant : de nouvelles
      // minutes ont pu s'ajouter pendant que la requête voyageait.
      await prefs.setInt(cle, (prefs.getInt(cle) ?? 0) - du);
    }
  }

  static Future<void> _viderLivres(SharedPreferences prefs, String uid) async {
    final prefixe = '$_cleLivre${uid}_';
    final cles = prefs.getKeys().where((k) => k.startsWith(prefixe)).toList();

    for (final cle in cles) {
      final solde = prefs.getInt(cle) ?? 0;
      if (solde <= 0) {
        await prefs.remove(cle);
        continue;
      }
      final du = solde > _maxMinutesParEnvoi ? _maxMinutesParEnvoi : solde;

      final livreId = cle.substring(prefixe.length);
      if (await _service.recordReadingTime(livreId, minutes: du)) {
        final reste = (prefs.getInt(cle) ?? 0) - du;
        if (reste > 0) {
          await prefs.setInt(cle, reste);
        } else {
          await prefs.remove(cle);
        }
      }
    }
  }

  /// Ce qui attend encore, pour le lecteur. Sert aux tests et au diagnostic.
  @visibleForTesting
  static Future<int> resteDuLecteur() async {
    final uid = await _utilisateur();
    if (uid == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_cleLecteur$uid') ?? 0;
  }

  @visibleForTesting
  static Future<int> resteDuLivre(String livreId) async {
    final uid = await _utilisateur();
    if (uid == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_cleLivre${uid}_$livreId') ?? 0;
  }
}
