import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/auteurService.dart';

/// L'annuaire des auteurs, vu du client.
///
/// L'ecran deduisait auparavant les auteurs des livres qu'il chargeait — deux
/// cents au plus. Le decompte affiche ne comptait donc que les livres recus, et
/// la liste ne pouvait pas etre paginee puisqu'elle derivait d'une autre.
///
/// Ces tests portent sur le contrat de la route : ce qu'on lui demande, et ce
/// qu'on fait de sa reponse.
void main() {
  ({AuteurService service, List<http.Request> appels}) serveur(
    List<Map<String, dynamic>> Function(int page, int limite) pageDe,
  ) {
    final appels = <http.Request>[];

    final client = MockClient((requete) async {
      appels.add(requete);
      final limite = int.parse(requete.url.queryParameters['limit'] ?? '20');
      final page = int.parse(requete.url.queryParameters['page'] ?? '1');
      return http.Response(jsonEncode({'data': pageDe(page, limite)}), 200);
    });

    return (service: AuteurService(client: client), appels: appels);
  }

  /// Un annuaire de [total] auteurs, servi page par page.
  ({AuteurService service, List<http.Request> appels}) annuaireDe(int total) {
    return serveur((page, limite) {
      final debut = (page - 1) * limite;
      return [
        for (var i = debut; i < debut + limite && i < total; i++)
          {
            'id': 'auteur-$i',
            'nom_complet': 'Auteur $i',
            'nombre_livres': total - i,
            'specialite': 'Roman',
            'est_suivi': false,
          },
      ];
    });
  }

  group('Le compte vient du serveur', () {
    /// Le defaut d'origine : le decompte etait calcule sur les livres charges.
    test('le nombre de livres est lu tel quel', () async {
      final s = serveur(
        (_, _) => [
          {
            'id': 'a1',
            'nom_complet': 'Kadi Traore',
            'nombre_livres': 47,
            'specialite': 'Essai',
            'est_suivi': true,
          },
        ],
      );

      final auteurs = await s.service.getAuteurs();

      expect(auteurs.single.nombreLivres, 47);
      expect(auteurs.single.specialite, 'Essai');
      expect(auteurs.single.estSuivi, isTrue);
    });

    /// Sans ces champs, l'ecran doit rester debout : un serveur d'une version
    /// anterieure ne les envoie pas.
    test('une reponse sans les nouveaux champs ne fait pas tomber la page', () async {
      final s = serveur((_, _) => [
        {'id': 'a1', 'nom_complet': 'Sans detail'},
      ]);

      final auteur = (await s.service.getAuteurs()).single;

      expect(auteur.nombreLivres, 0);
      expect(auteur.specialite, isNull);
      expect(auteur.estSuivi, isFalse);
    });

    test('un nom vide ne fait pas planter l\'initiale', () async {
      final s = serveur((_, _) => [
        {'id': 'a1', 'nom_complet': ''},
      ]);

      expect((await s.service.getAuteurs()).single.initiale, '?');
    });
  });

  group('La liste se pagine', () {
    test('chaque appel porte page et limit', () async {
      final s = annuaireDe(5);

      await s.service.getAuteurs();

      expect(s.appels.single.url.queryParameters['page'], '1');
      expect(s.appels.single.url.queryParameters['limit'], isNotNull);
    });

    test('la page demandee est celle qui est rendue', () async {
      final s = annuaireDe(100);

      final page2 = await s.service.getAuteurs(page: 2, limit: 20);

      expect(page2.length, 20);
      expect(page2.first.id, 'auteur-20');
    });

    test('une page au-dela de la fin est vide, sans erreur', () async {
      final s = annuaireDe(3);

      expect(await s.service.getAuteurs(page: 9), isEmpty);
    });
  });

  group('La recherche part au serveur', () {
    test('un terme utilisable est transmis', () async {
      final s = annuaireDe(3);

      await s.service.getAuteurs(recherche: 'traore');

      expect(s.appels.single.url.queryParameters['q'], 'traore');
    });

    /// Une lettre seule ne restreint rien et coute au serveur un parcours
    /// complet : le client ne la lui envoie pas.
    test('un terme trop court n\'est pas transmis', () async {
      final s = annuaireDe(3);

      await s.service.getAuteurs(recherche: 'a');

      expect(s.appels.single.url.queryParameters.containsKey('q'), isFalse);
    });
  });

  group('Un refus du serveur ne passe pas pour un annuaire vide', () {
    /// Rendre une liste vide sur un 429 afficherait « aucun auteur » — et
    /// personne n'irait chercher du cote du serveur.
    test('un refus leve', () async {
      final service = AuteurService(
        client: MockClient(
          (_) async => http.Response('{"message":"Trop de requetes."}', 429),
        ),
      );

      expect(service.getAuteurs(), throwsA(isA<Exception>()));
    });

    test('le jeton est transmis quand il existe', () async {
      final s = annuaireDe(1);

      await s.service.getAuteurs(authToken: 'jeton');

      expect(s.appels.single.headers['Authorization'], 'Bearer jeton');
    });

    test('aucun en-tete d\'autorisation sans jeton', () async {
      final s = annuaireDe(1);

      await s.service.getAuteurs();

      expect(s.appels.single.headers.containsKey('Authorization'), isFalse);
    });
  });
}
