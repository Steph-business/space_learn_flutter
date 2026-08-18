import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
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

  CreneauLecture copyWith({int? heure, int? minute, Set<int>? jours, bool? actif}) =>
      CreneauLecture(
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

  static Future<String> _cleUtilisateur() async {
    final id = await TokenStorage.getUserId();
    return '$_cle${id ?? 'invite'}';
  }

  /// Prépare les fuseaux. Sans cela, `zonedSchedule` lève à la première mise
  /// en attente, et le rappel ne serait pas programmé du tout.
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
  static Future<void> enregistrer(List<CreneauLecture> creneaux) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      await _cleUtilisateur(),
      creneaux.map((c) => jsonEncode(c.toJson())).toList(),
    );
    await reprogrammer(creneaux);
    await _pousserAuServeur(creneaux);
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
            scheduledDate: _prochaineOccurrence(jour, creneau.heure, creneau.minute),
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

      final reponse = await http.get(
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

  static Future<void> _pousserAuServeur(List<CreneauLecture> creneaux) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;

      await http.put(
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
    } catch (_) {
      // Les créneaux sont déjà enregistrés localement et programmés : un
      // serveur injoignable ne doit pas priver le lecteur de ses rappels.
    }
  }

  /// Rapatrie les créneaux du compte et les reprogramme sur cet appareil.
  ///
  /// À appeler à l'ouverture de l'écran : c'est ce qui fait qu'un lecteur
  /// retrouve ses habitudes après avoir réinstallé l'application.
  static Future<List<CreneauLecture>> synchroniser() async {
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
