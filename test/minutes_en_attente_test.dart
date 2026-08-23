import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/minutes_en_attente.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/readerStatsService.dart';

/// Les minutes de lecture qui n'ont pas encore atteint le serveur.
///
/// La page de lecture les retranchait de son solde AVANT de savoir si le
/// serveur les avait acceptées, et ce solde vivait dans un champ d'instance.
/// Deux pertes : lire sans réseau n'atteignait jamais le serveur, et fermer un
/// livre effaçait ce qui attendait.

/// Un faux serveur qui note ce qu'on lui envoie et peut refuser.
class _Serveur {
  bool accepteLecteur = true;
  bool accepteLivre = true;

  final List<int> minutesLecteur = [];
  final List<({String livre, int minutes})> minutesLivre = [];

  http.Client get client => MockClient((requete) async {
    final corps = jsonDecode(requete.body) as Map<String, dynamic>;

    if (requete.url.path.endsWith('/reading/temps')) {
      if (!accepteLecteur) return http.Response('{}', 503);
      minutesLecteur.add((corps['minutes'] as num).toInt());
      return http.Response('{"ok":true}', 200);
    }

    // POST /api/reading/activity — la seule route ouverte aux lecteurs pour
    // déposer des minutes sur un livre.
    //
    // Ce faux serveur reproduisait auparavant le contrat que le client
    // imaginait : un PUT sur `detailed-stats/:livre_id` portant un champ
    // `reading_time_increment`. Ni la route ni le champ n'acceptent cela — la
    // route est réservée à l'auteur du livre, et le champ n'existe pas. Le test
    // passait donc en prouvant que le client s'entend avec lui-même, pendant
    // que le vrai serveur répondait 403 à chaque envoi.
    if (!accepteLivre) return http.Response('{}', 503);
    minutesLivre.add((
      livre: corps['livre_id'] as String,
      minutes: (corps['duree_minutes'] as num).toInt(),
    ));
    return http.Response('{"ok":true}', 201);
  });
}

void main() {
  late _Serveur serveur;

  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 'lecteur-1'});
    // Le jeton vit dans le coffre chiffré de la plateforme, indisponible en
    // test : sans lui, declarerMinutes renonce avant même d'appeler le serveur.
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'jeton-de-test'});
    serveur = _Serveur();
    MinutesEnAttente.service = ReaderStatsService(client: serveur.client);
  });

  group('Accumulation', () {
    /// Le battement local tombe toutes les quinze secondes ; le serveur compte
    /// en minutes. Déclarer « une minute » à chaque battement avait multiplié
    /// par quatre le temps de lecture affiché aux auteurs.
    test('rien ne part avant une minute pleine', () async {
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 15);
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 15);
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 15);

      expect(serveur.minutesLecteur, isEmpty);
      expect(serveur.minutesLivre, isEmpty);

      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 15);

      expect(serveur.minutesLecteur, [1]);
      expect(serveur.minutesLivre.single.minutes, 1);
      expect(serveur.minutesLivre.single.livre, 'livre-a');
    });

    test('le reliquat de secondes n\'est pas perdu', () async {
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 90);
      expect(serveur.minutesLecteur, [1]);

      // Les 30 secondes restantes plus 30 nouvelles font la minute suivante.
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 30);
      expect(serveur.minutesLecteur, [1, 1]);
    });
  });

  group('Quand le serveur refuse', () {
    /// Le cœur du correctif : rien ne se perd.
    test('les minutes restent en attente et repartent plus tard', () async {
      serveur.accepteLecteur = false;
      serveur.accepteLivre = false;

      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 120);

      expect(serveur.minutesLecteur, isEmpty);
      expect(await MinutesEnAttente.resteDuLecteur(), 2);
      expect(await MinutesEnAttente.resteDuLivre('livre-a'), 2);

      // Le réseau revient.
      serveur.accepteLecteur = true;
      serveur.accepteLivre = true;
      await MinutesEnAttente.vider();

      expect(serveur.minutesLecteur, [2]);
      expect(serveur.minutesLivre.single.minutes, 2);
      expect(await MinutesEnAttente.resteDuLecteur(), 0);
    });

    /// Le piège précis que deux soldes séparés évitent.
    ///
    /// Avec un compteur unique, l'échec d'une destination ferait tout renvoyer
    /// — y compris à celle qui avait déjà compté ces minutes. C'est ce qui
    /// avait gonflé d'un facteur quatre les statistiques des auteurs.
    test(
      'un échec sur une destination ne fait pas renvoyer l\'autre',
      () async {
        serveur.accepteLecteur = true;
        serveur.accepteLivre = false;

        await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 60);

        expect(serveur.minutesLecteur, [1], reason: 'le lecteur a bien reçu');
        expect(await MinutesEnAttente.resteDuLecteur(), 0);
        expect(await MinutesEnAttente.resteDuLivre('livre-a'), 1);

        serveur.accepteLivre = true;
        await MinutesEnAttente.vider();

        expect(
          serveur.minutesLecteur,
          [1],
          reason: 'la minute a été comptée deux fois au lecteur',
        );
        expect(serveur.minutesLivre.single.minutes, 1);
      },
    );

    test('les soldes s\'additionnent pendant la panne', () async {
      serveur.accepteLecteur = false;
      serveur.accepteLivre = false;

      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 60);
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 60);
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 60);

      expect(await MinutesEnAttente.resteDuLecteur(), 3);

      serveur.accepteLecteur = true;
      serveur.accepteLivre = true;
      await MinutesEnAttente.vider();

      // Un seul envoi de trois minutes, pas trois envois d'une.
      expect(serveur.minutesLecteur, [3]);
    });
  });

  group('Plusieurs livres', () {
    test('chaque livre garde son propre solde', () async {
      serveur.accepteLivre = false;

      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 60);
      await MinutesEnAttente.porter(livreId: 'livre-b', secondes: 120);

      expect(await MinutesEnAttente.resteDuLivre('livre-a'), 1);
      expect(await MinutesEnAttente.resteDuLivre('livre-b'), 2);

      serveur.accepteLivre = true;
      await MinutesEnAttente.vider();

      final parLivre = {
        for (final e in serveur.minutesLivre) e.livre: e.minutes,
      };
      expect(parLivre, {'livre-a': 1, 'livre-b': 2});
    });

    /// Le temps du lecteur ne dépend pas du livre : les minutes des deux
    /// s'additionnent sur un seul compte.
    test('le temps du lecteur cumule tous les livres', () async {
      serveur.accepteLecteur = false;
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 60);
      await MinutesEnAttente.porter(livreId: 'livre-b', secondes: 60);

      expect(await MinutesEnAttente.resteDuLecteur(), 2);
    });
  });

  group('Soldes hors normes', () {
    /// Le serveur refuse au-delà de 480 minutes : une séance de huit heures
    /// n'est pas crédible. Sans plafond côté client, un solde qui dépassait ce
    /// seuil était rejeté à CHAQUE tentative — il ne repartait donc jamais et
    /// grossissait indéfiniment dans les préférences.
    test('un solde au-dessus du plafond part par tranches', () async {
      // 600 minutes accumulées : dix heures hors réseau, ou des mois de
      // minutes par livre qui n'ont jamais pu partir.
      serveur.accepteLecteur = false;
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 600 * 60);
      expect(serveur.minutesLecteur, isEmpty);

      serveur.accepteLecteur = true;
      await MinutesEnAttente.vider();

      // Une première tranche part, plafonnée.
      expect(serveur.minutesLecteur, [480]);
      expect(await MinutesEnAttente.resteDuLecteur(), 120);

      // Le reste suit au passage suivant : rien n'est perdu, rien ne bloque.
      await MinutesEnAttente.vider();
      expect(serveur.minutesLecteur, [480, 120]);
      expect(await MinutesEnAttente.resteDuLecteur(), 0);
    });

    test("le solde d'un livre part aussi par tranches", () async {
      serveur.accepteLivre = false;
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 500 * 60);
      expect(serveur.minutesLivre, isEmpty);

      serveur.accepteLivre = true;
      await MinutesEnAttente.vider();

      expect(serveur.minutesLivre.map((e) => e.minutes).toList(), [480]);
      expect(await MinutesEnAttente.resteDuLivre('livre-a'), 20);
    });
  });

  group('Cas limites', () {
    test('sans compte connecté, rien n\'est envoyé', () async {
      SharedPreferences.setMockInitialValues({});
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 120);
      expect(serveur.minutesLecteur, isEmpty);
    });

    test(
      'une lecture sans identifiant de livre crédite quand même le lecteur',
      () async {
        await MinutesEnAttente.porter(livreId: null, secondes: 60);
        expect(serveur.minutesLecteur, [1]);
        expect(serveur.minutesLivre, isEmpty);
      },
    );

    test('zéro seconde ne déclenche rien', () async {
      await MinutesEnAttente.porter(livreId: 'livre-a', secondes: 0);
      expect(serveur.minutesLecteur, isEmpty);
    });

    /// Vider sur un solde vide ne doit pas envoyer « 0 minute ».
    test('vider à vide n\'appelle pas le serveur', () async {
      await MinutesEnAttente.vider();
      expect(serveur.minutesLecteur, isEmpty);
      expect(serveur.minutesLivre, isEmpty);
    });
  });
}
