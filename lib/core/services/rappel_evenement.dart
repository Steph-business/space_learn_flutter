import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:space_learn_flutter/core/services/rappels_lecture.dart';

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

  static const String _cle = 'rappels_evenements';

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
      return (prefs.getStringList(_cle) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> estPose(String evenementId) async =>
      (await poses()).contains(evenementId);

  /// La date à laquelle le rappel doit sonner, ou null si elle est dépassée.
  ///
  /// Un rendez-vous dont la veille est passée ne peut plus être rappelé : le
  /// proposer serait promettre une notification qui ne partirait jamais.
  static tz.TZDateTime? quandSonner(DateTime dateEvenement) {
    final veille = dateEvenement.subtract(const Duration(days: 1));
    final quand = tz.TZDateTime(
      tz.local,
      veille.year,
      veille.month,
      veille.day,
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
      final liste = (prefs.getStringList(_cle) ?? const []).toSet();
      pose ? liste.add(id) : liste.remove(id);
      await prefs.setStringList(_cle, liste.toList());
    } catch (e) {
      // La notification est posée ; ne pas l'avoir notée fera seulement que le
      // bouton reparaîtra « à poser ». Mieux vaut ça qu'échouer l'opération.
      debugPrint('Rappel non mémorisé : $e');
    }
  }
}
