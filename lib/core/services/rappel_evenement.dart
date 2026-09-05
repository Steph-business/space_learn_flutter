import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:space_learn_flutter/core/services/rappels_lecture.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Se faire rappeler un rendez-vous.
///
/// C'est ce qui sépare vraiment un événement d'une annonce. Une annonce se lit,
/// ou pas. Un rendez-vous, on peut le MANQUER — et jusqu'ici l'application se
/// contentait d'en afficher la date, à charge pour le lecteur de la retenir.
///
/// Le rappel est local, comme celui des créneaux de lecture : aucun serveur à
/// joindre, il part même hors connexion. Il réutilise la même machinerie, déjà
/// éprouvée — fuseaux préparés, mode inexact pour éviter l'autorisation
/// d'alarme exacte qu'Android restreint.
class RappelEvenement {
  RappelEvenement._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Plage d'identifiants réservée aux rendez-vous.
  ///
  /// Distincte de celle des créneaux de lecture (900000) : annuler les rappels
  /// d'un côté ne doit pas emporter ceux de l'autre. C'est ce genre de
  /// chevauchement qui fait disparaître des notifications sans explication.
  static const int _baseId = 700000;

  /// Préfixe des clés de stockage. Jamais utilisé seul : voir [_cleDuCompte].
  static const String _cle = 'rappels_evenements';

  /// La clé de CE compte.
  ///
  /// Elle était fixe, donc commune à tout le téléphone. La personne suivante à
  /// s'y connecter voyait « Rappel posé » sur des rendez-vous qu'elle n'avait
  /// jamais notés, pouvait « retirer » un rappel qui n'était pas le sien, et
  /// recevait à 18 h la veille les notifications programmées par le compte
  /// précédent. Ce qui est LOCAL et PAR COMPTE porte l'identifiant du compte
  /// dans sa clé — même règle que le cache des badges.
  ///
  /// Compte inconnu : le suffixe est vide. La liste est alors celle d'un
  /// « personne », que [purgerEtAnnuler] emporte comme les autres.
  static Future<String> _cleDuCompte() async {
    final compte = await TokenStorage.getUserId() ?? '';
    return '${_cle}_$compte';
  }

  /// La veille, en fin d'après-midi.
  ///
  /// Prévenir le jour même laisse trop peu de temps pour s'organiser ; une
  /// semaine avant, on oublie de nouveau. 18 h la veille tombe au moment où
  /// l'on regarde sa soirée et son lendemain.
  static const int _heureRappel = 18;

  /// L'identifiant de notification d'un événement.
  ///
  /// Dérivé de son identifiant : le même événement retrouve toujours le même
  /// numéro, ce qui permet d'annuler un rappel qu'une session précédente avait
  /// posé — sans tenir de table de correspondance.
  static int _idPour(String evenementId) =>
      _baseId + (evenementId.hashCode.abs() % 100000);

  /// Les événements pour lesquels un rappel est posé.
  static Future<Set<String>> poses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(await _cleDuCompte()) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Oublie les rappels du téléphone ET annule ceux déjà programmés.
  ///
  /// Appelée par SessionService.terminer, le point de nettoyage unique.
  /// Effacer la seule liste ne suffisait pas : les notifications sont déjà
  /// déposées chez le système d'exploitation, et sonnaient chez le compte
  /// suivant — « Demain : atelier d'écriture » pour un rendez-vous que la
  /// personne devant l'écran n'a jamais noté, ni même vu.
  ///
  /// On balaye TOUTES les clés du préfixe, y compris l'ancienne clé sans
  /// suffixe laissée par les versions précédentes : ses rappels-là sonnent
  /// encore, et personne ne peut plus les retirer depuis l'application.
  static Future<void> purgerEtAnnuler() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cles = prefs
          .getKeys()
          .where((k) => k == _cle || k.startsWith('${_cle}_'))
          .toList();

      for (final cle in cles) {
        for (final id in prefs.getStringList(cle) ?? const <String>[]) {
          try {
            await _plugin.cancel(id: _idPour(id));
          } catch (e) {
            debugPrint('Rappel non annulé pour $id : $e');
          }
        }
        await prefs.remove(cle);
      }
    } catch (e) {
      // Une purge qui échoue ne doit pas empêcher la déconnexion de finir.
      debugPrint("Rappels d'événements non purgés : $e");
    }
  }

  static Future<bool> estPose(String evenementId) async =>
      (await poses()).contains(evenementId);

  /// La date à laquelle le rappel doit sonner, ou null si elle est dépassée.
  ///
  /// Un rendez-vous dont la veille est passée ne peut plus être rappelé : le
  /// proposer serait promettre une notification qui ne partirait jamais.
  static tz.TZDateTime? quandSonner(DateTime dateEvenement) {
    // La veille de la date LOCALE de la personne qui sera prévenue.
    //
    // Un rendez-vous est un instant ; un rappel, lui, se cale sur un jour et
    // une heure vécus — 18 h la veille, chez soi. La date arrive déjà en heure
    // locale (evenementModel la convertit au bord), mais `toLocal()` reste ici
    // en filet : un instant brut, resté en UTC, aurait donné SA veille à lui.
    // Un rendez-vous du 10 à 1 h du matin en UTC+3, c'est le 9 à 22 h en UTC —
    // le rappel serait tombé le 8 au soir, deux jours trop tôt. `toLocal()` ne
    // change rien à une date déjà locale : l'appliquer n'ajoute aucun décalage.
    final local = dateEvenement.toLocal();

    // `day - 1` plutôt qu'un `subtract` de 24 h : les deux ne disent pas la
    // même chose la nuit d'un changement d'heure, où la journée dure 23 ou
    // 25 h et où retrancher une durée fixe change de jour civil. Le
    // constructeur normalise le 0 en dernier jour du mois précédent.
    final quand = tz.TZDateTime(
      tz.local,
      local.year,
      local.month,
      local.day - 1,
      _heureRappel,
    );
    return quand.isAfter(tz.TZDateTime.now(tz.local)) ? quand : null;
  }

  /// Peut-on encore poser un rappel pour ce rendez-vous ?
  static bool encorePossible(DateTime? dateEvenement) {
    if (dateEvenement == null) return false;
    try {
      return quandSonner(dateEvenement) != null;
    } catch (_) {
      // Fuseaux pas encore préparés : on laisse le bouton, `poser` s'en
      // chargera. Refuser ici priverait du rappel au premier lancement.
      //
      // `isAfter` compare deux INSTANTS, pas deux heures murales : il reste
      // juste que la date soit locale ou UTC, ce qui n'est pas le cas des
      // comparaisons faites sur les champs (année, mois, jour) d'une date.
      return dateEvenement.isAfter(DateTime.now());
    }
  }

  /// Pose le rappel. Rend `false` si le moment est déjà passé.
  static Future<bool> poser({
    required String evenementId,
    required String titre,
    required DateTime dateEvenement,
  }) async {
    await RappelsLecture.preparerFuseau();

    final quand = quandSonner(dateEvenement);
    if (quand == null) return false;

    try {
      await _plugin.zonedSchedule(
        id: _idPour(evenementId),
        title: 'Demain : $titre',
        body: "C'est le rendez-vous que vous aviez noté.",
        scheduledDate: quand,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rappels_evenements',
            'Rappels de rendez-vous',
            channelDescription: 'Les événements que vous avez notés',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Même mode que les créneaux de lecture : l'alarme exacte demande une
        // autorisation qu'Android restreint depuis la version 12, et une
        // minute d'imprécision la veille au soir n'a aucune conséquence.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Rappel non programmé pour $evenementId : $e');
      return false;
    }

    await _memoriser(evenementId, pose: true);
    return true;
  }

  static Future<void> retirer(String evenementId) async {
    try {
      await _plugin.cancel(id: _idPour(evenementId));
    } catch (e) {
      debugPrint('Rappel non annulé pour $evenementId : $e');
    }
    await _memoriser(evenementId, pose: false);
  }

  static Future<void> _memoriser(String id, {required bool pose}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cle = await _cleDuCompte();
      final liste = (prefs.getStringList(cle) ?? const []).toSet();
      pose ? liste.add(id) : liste.remove(id);
      await prefs.setStringList(cle, liste.toList());
    } catch (e) {
      // La notification est posée ; ne pas l'avoir notée fera seulement que le
      // bouton reparaîtra « à poser ». Mieux vaut ça qu'échouer l'opération.
      debugPrint('Rappel non mémorisé : $e');
    }
  }
}
