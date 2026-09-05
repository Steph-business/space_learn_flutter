import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:space_learn_flutter/core/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:space_learn_flutter/core/utils/api_routes.dart';
import 'package:space_learn_flutter/core/utils/token_storage.dart';

/// Un créneau de lecture : une heure, et les jours où elle revient.
///
/// Le réglage précédent n'offrait qu'une heure unique, la même sept jours sur
/// sept. Or on ne lit pas à la même heure un mardi et un dimanche : imposer un
/// rappel à 20 h 30 le samedi, c'est le faire ignorer, puis désactiver.
class CreneauLecture {
  const CreneauLecture({
    required this.heure,
    required this.minute,
    required this.jours,
    this.actif = true,
  });

  final int heure;
  final int minute;

  /// Jours de la semaine, à la façon de DateTime : 1 = lundi … 7 = dimanche.
  final Set<int> jours;
  final bool actif;

  String get libelleHeure =>
      '${heure.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// « Tous les jours », « En semaine », « Le week-end », ou la liste.
  String get libelleJours {
    if (jours.length == 7) return 'Tous les jours';
    if (jours.length == 5 && jours.containsAll({1, 2, 3, 4, 5})) {
      return 'En semaine';
    }
    if (jours.length == 2 && jours.containsAll({6, 7})) return 'Le week-end';

    const noms = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final tries = jours.toList()..sort();
    return tries.map((j) => noms[j - 1]).join(', ');
  }

  Map<String, dynamic> toJson() => {
    'heure': heure,
    'minute': minute,
    'jours': jours.toList(),
    'actif': actif,
  };

  factory CreneauLecture.fromJson(Map<String, dynamic> json) {
    final bruts = (json['jours'] as List?) ?? const [];
    return CreneauLecture(
      heure: (json['heure'] as num?)?.toInt() ?? 20,
      minute: (json['minute'] as num?)?.toInt() ?? 30,
      jours: bruts.map((j) => (j as num).toInt()).toSet(),
      actif: json['actif'] != false,
    );
  }

  CreneauLecture copyWith({
    int? heure,
    int? minute,
    Set<int>? jours,
    bool? actif,
  }) => CreneauLecture(
    heure: heure ?? this.heure,
    minute: minute ?? this.minute,
    jours: jours ?? this.jours,
    actif: actif ?? this.actif,
  );
}

/// Les rappels de lecture, et leur programmation réelle auprès du système.
///
/// Ce qui existait n'était qu'un réglage : une heure écrite dans les
/// préférences, une bascule verte, et aucune notification jamais programmée.
/// `flutter_local_notifications` était bien présent, mais le code n'appelait
/// que `show()` — un affichage immédiat. Le lecteur croyait recevoir un rappel
/// à 20 h 30 ; rien ne partait, jamais.
class RappelsLecture {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _cle = 'rappels_lecture_';
  static bool _fuseauPret = false;

  /// Identifiants réservés aux rappels.
  ///
  /// Une plage à part, pour que l'annulation n'emporte pas les notifications
  /// venues du serveur, qui portent le hash de leur identifiant.
  static const int _baseId = 900000;

  /// Le drapeau « des créneaux attendent d'être poussés au compte ».
  ///
  /// Il commence par [_cle] à dessein : [purgerEtAnnuler] balaie tout ce
  /// préfixe, et ce drapeau part donc avec les créneaux à la déconnexion.
  static const String _cleAttente = '${_cle}a_pousser_';

  static Future<String> _cleUtilisateur() async {
    final id = await TokenStorage.getUserId();
    return '$_cle${id ?? 'invite'}';
  }

  static Future<String> _cleUtilisateurAttente() async {
    final id = await TokenStorage.getUserId();
    return '$_cleAttente${id ?? 'invite'}';
  }

  /// Oublie les créneaux de CET appareil et annule leurs notifications.
  ///
  /// Appelée par SessionService.terminer, le point de nettoyage unique — et
  /// pour la même raison que RappelEvenement.purgerEtAnnuler : les
  /// notifications hebdomadaires sont DÉJÀ DÉPOSÉES chez le système
  /// d'exploitation. Sans cette purge, elles continuaient de sonner « C'est
  /// votre moment de lecture » chez le compte suivant du téléphone — partagé
  /// en famille, revendu, ou simple passage du profil lecteur au profil
  /// auteur — qui n'avait AUCUN moyen de les éteindre : son écran « Temps de
  /// lecture » lit sa propre clé, et affichait une liste vide pendant que les
  /// rappels de quelqu'un d'autre sonnaient chaque semaine. La liste de
  /// l'ancien compte restait par-dessus le marché sur l'appareil, avec ce
  /// qu'elle dit de ses habitudes.
  ///
  /// Le balayage se fait par PRÉFIXE et non par [_cleUtilisateur] : l'étape
  /// « jeton » de la déconnexion a déjà effacé l'identifiant du compte, si
  /// bien qu'une purge nominative ne viderait que le seau « invite ». C'est
  /// exactement le piège documenté dans rappel_evenement.dart. On emporte donc
  /// aussi les clés des autres comptes de l'appareil et celle des invités.
  static Future<void> purgerEtAnnuler() async {
    // D'abord les notifications : la plage 900000..900059 couvre les créneaux
    // de TOUS les comptes de l'appareil, elle ne dépend d'aucune clé.
    try {
      await annulerTout();
    } catch (e) {
      debugPrint('Rappels de lecture non annulés : $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // `toList()` : on retire des clés pendant qu'on les parcourt.
      final cles = prefs.getKeys().where((k) => k.startsWith(_cle)).toList();
      for (final cle in cles) {
        await prefs.remove(cle);
      }
    } catch (e) {
      // Une purge qui échoue ne doit pas empêcher la déconnexion de finir.
      debugPrint('Créneaux de lecture non effacés : $e');
    }
  }

  /// Prépare les fuseaux. Sans cela, `zonedSchedule` lève à la première mise
  /// en attente, et le rappel ne serait pas programmé du tout.
  /// Publique : les rappels de rendez-vous en ont besoin aussi, et preparer
  /// les fuseaux deux fois de deux facons differentes finirait par donner deux
  /// resultats.
  static Future<void> preparerFuseau() => _preparerFuseau();

  static Future<void> _preparerFuseau() async {
    if (_fuseauPret) return;
    tzdata.initializeTimeZones();
    try {
      // getLocalTimezone rend un objet, pas une chaîne, depuis la version 5.
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Un fuseau inconnu ne doit pas priver le lecteur de ses rappels : on
      // retombe sur celui d'Abidjan, qui couvre le public visé.
      debugPrint('Fuseau local indisponible ($e) : repli sur Africa/Abidjan');
      tz.setLocalLocation(tz.getLocation('Africa/Abidjan'));
    }
    _fuseauPret = true;
  }

  static Future<List<CreneauLecture>> lire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getStringList(await _cleUtilisateur());
      if (brut == null) return const [];
      return brut
          .map((s) {
            try {
              return CreneauLecture.fromJson(jsonDecode(s));
            } catch (_) {
              return null;
            }
          })
          .whereType<CreneauLecture>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Enregistre les créneaux ET les programme auprès du système.
  ///
  /// Les deux vont ensemble : un créneau enregistré sans être programmé est
  /// précisément le défaut qu'on corrige ici.
  ///
  /// Rend `true` seulement si le COMPTE a été mis à jour, c'est-à-dire si le
  /// serveur a confirmé. L'écran appelant n'a pas le droit d'annoncer autre
  /// chose que ce qui s'est réellement passé : les créneaux sont posés sur cet
  /// appareil dans tous les cas, mais un `false` veut dire qu'ils n'existent
  /// nulle part ailleurs pour l'instant.
  static Future<bool> enregistrer(List<CreneauLecture> creneaux) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      await _cleUtilisateur(),
      creneaux.map((c) => jsonEncode(c.toJson())).toList(),
    );
    await reprogrammer(creneaux);
    return _pousserAuServeur(creneaux);
  }

  /// Reprogramme tout : on annule d'abord, sinon un créneau supprimé
  /// continuerait de sonner et un créneau modifié sonnerait deux fois.
  static Future<void> reprogrammer(List<CreneauLecture> creneaux) async {
    await _preparerFuseau();
    await annulerTout();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'rappels_lecture',
        'Rappels de lecture',
        channelDescription: 'Vos créneaux de lecture',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    var index = 0;
    for (final creneau in creneaux) {
      if (!creneau.actif) continue;
      for (final jour in creneau.jours) {
        try {
          await _plugin.zonedSchedule(
            id: _baseId + index,
            title: 'C\'est votre moment de lecture',
            body: 'Quelques pages vous attendent.',
            scheduledDate: _prochaineOccurrence(
              jour,
              creneau.heure,
              creneau.minute,
            ),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            // Chaque semaine, au même jour et à la même heure.
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          debugPrint('Rappel non programmé (jour $jour) : $e');
        }
        index++;
      }
    }
  }

  static Future<void> annulerTout() async {
    // Une plage généreuse : sept jours par créneau, et l'on n'en attend pas
    // plus d'une poignée.
    for (var i = 0; i < 60; i++) {
      try {
        await _plugin.cancel(id: _baseId + i);
      } catch (_) {}
    }
  }

  /// La prochaine fois que ce jour de la semaine tombera à cette heure.
  ///
  /// Si l'heure est déjà passée aujourd'hui, on vise la semaine suivante :
  /// programmer dans le passé ferait sonner la notification immédiatement.
  static tz.TZDateTime _prochaineOccurrence(int jour, int heure, int minute) {
    final maintenant = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(
      tz.local,
      maintenant.year,
      maintenant.month,
      maintenant.day,
      heure,
      minute,
    );

    while (date.weekday != jour || !date.isAfter(maintenant)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  // ── Synchronisation avec le compte ────────────────────────────────────────

  /// Les créneaux tels que le serveur les connaît.
  ///
  /// La notification est forcément locale — c'est le téléphone qui la déclenche
  /// — mais le RÉGLAGE ne l'est pas. Le garder dans les seules préférences
  /// signifiait qu'une réinstallation, ou un changement d'appareil, effaçait
  /// les habitudes de lecture d'une personne sans l'en avertir autrement que
  /// par le silence.
  static Future<List<CreneauLecture>?> _lireDuServeur() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return null;

      final reponse = await ApiClient.instance.get(
        Uri.parse(ApiRoutes.readingCreneaux),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (reponse.statusCode != 200) return null;

      final corps = jsonDecode(reponse.body);
      final data = (corps is Map ? corps['data'] : null) ?? corps;
      if (data is! List) return null;

      return data
          .map((j) {
            try {
              final m = j as Map<String, dynamic>;
              final jours = (m['jours'] as String? ?? '')
                  .split(',')
                  .map((s) => int.tryParse(s.trim()))
                  .whereType<int>()
                  .toSet();
              if (jours.isEmpty) return null;
              return CreneauLecture(
                heure: (m['heure'] as num?)?.toInt() ?? 20,
                minute: (m['minute'] as num?)?.toInt() ?? 30,
                jours: jours,
                actif: m['actif'] != false,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<CreneauLecture>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Porte les créneaux au compte. Rend `true` sur confirmation du serveur.
  ///
  /// Le code de réponse n'était même pas regardé, et toute exception tombait
  /// dans un `catch (_) {}` muet : l'appelant ne pouvait pas savoir que rien
  /// n'était parti, et l'écran annonçait « Rappels programmés » de toute
  /// façon. Un échec pose maintenant un drapeau d'attente, que [synchroniser]
  /// relit avant d'accepter quoi que ce soit du serveur.
  static Future<bool> _pousserAuServeur(List<CreneauLecture> creneaux) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return false;

      final reponse = await ApiClient.instance.put(
        Uri.parse(ApiRoutes.readingCreneaux),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'creneaux': creneaux
              .map(
                (c) => {
                  'heure': c.heure,
                  'minute': c.minute,
                  'jours': (c.jours.toList()..sort()).join(','),
                  'actif': c.actif,
                },
              )
              .toList(),
        }),
      );

      if (reponse.statusCode == 200) {
        await _marquerAttente(false);
        return true;
      }

      // Un refus de CONTENU (400 : créneau invalide, plus de vingt créneaux)
      // ne se rejoue pas : renvoyer la même liste donnerait éternellement le
      // même 400, et le drapeau gèlerait la synchronisation pour toujours.
      // Tout le reste — 5xx, jeton expiré, passerelle — est temporaire.
      if (reponse.statusCode != 400) {
        await _marquerAttente(true);
      }
      return false;
    } catch (_) {
      // Réseau coupé ou serveur injoignable. Les créneaux sont déjà
      // enregistrés localement et programmés : un serveur muet ne doit pas
      // priver le lecteur de ses rappels — mais il ne doit pas non plus les
      // lui faire perdre au prochain passage sur l'écran.
      await _marquerAttente(true);
      return false;
    }
  }

  static Future<void> _marquerAttente(bool enAttente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cle = await _cleUtilisateurAttente();
      if (enAttente) {
        await prefs.setBool(cle, true);
      } else {
        await prefs.remove(cle);
      }
    } catch (e) {
      debugPrint("Drapeau d'envoi des créneaux non écrit : $e");
    }
  }

  static Future<bool> _envoiEnAttente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(await _cleUtilisateurAttente()) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Rapatrie les créneaux du compte et les reprogramme sur cet appareil.
  ///
  /// À appeler à l'ouverture de l'écran, et à l'ouverture de session : c'est
  /// ce qui fait qu'un lecteur retrouve ses habitudes après avoir réinstallé
  /// l'application ou s'être reconnecté.
  ///
  /// UN ENVOI EN ATTENTE PRIME SUR LE SERVEUR. Sans cette garde, la séquence
  /// la plus ordinaire du réseau mobile effaçait les rappels sans un mot :
  /// mardi soir sans données, le lecteur pose un créneau ; le PUT échoue en
  /// silence ; jeudi en wifi il rouvre l'écran, le serveur répond 200 avec une
  /// liste VIDE — GORM rend `[]`, jamais `null`, quand la table n'a aucune
  /// ligne, donc le garde-fou `data is! List` ne rattrape rien — et l'ancien
  /// code écrasait les préférences puis appelait `annulerTout()`. Écran vide,
  /// notifications annulées, aucune explication : le lecteur en conclut que
  /// « les rappels ne marchent pas » et coupe la fonction.
  ///
  /// La règle naïve « distant vide + local non vide → garder le local » ne
  /// convient pas : elle ressusciterait sur ce téléphone les créneaux
  /// volontairement supprimés depuis un autre. C'est bien le drapeau d'attente
  /// — donc un envoi qu'on SAIT n'être jamais parti — qui fait autorité.
  static Future<List<CreneauLecture>> synchroniser() async {
    if (await _envoiEnAttente()) {
      final locaux = await lire();
      if (!await _pousserAuServeur(locaux)) {
        // Toujours pas de réseau : la liste locale reste la source, rien n'est
        // écrasé et surtout rien n'est annulé.
        return locaux;
      }
      // Confirmé : le serveur porte désormais ces créneaux, et la relecture
      // ci-dessous peut redevenir la source sans rien perdre.
    }

    final distants = await _lireDuServeur();
    if (distants == null) {
      // Serveur muet : les créneaux locaux restent la seule source.
      return lire();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      await _cleUtilisateur(),
      distants.map((c) => jsonEncode(c.toJson())).toList(),
    );
    await reprogrammer(distants);
    return distants;
  }
}
