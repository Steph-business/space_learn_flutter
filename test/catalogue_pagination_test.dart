import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/bookService.dart';

/// Ce qu'un écran a le droit de charger.
///
/// Deux défauts opposés se succèdent ici, et les deux sont couverts.
///
/// Le premier : le serveur applique `DefaultQuery("limit", "10")` et le client
/// n'envoyait aucun paramètre. La boutique, la recherche, la liste des auteurs
/// et le rapport de ventes d'un auteur affichaient au plus dix titres, sans
/// message ni bouton « voir plus ».
///
/// Le second, introduit en corrigeant le premier : enchaîner les pages jusqu'à
/// la dernière. Correct sur trois livres, intenable sur un vrai catalogue —
/// l'accueil l'aurait téléchargé en entier à chaque ouverture. Tout chargement
/// porte désormais un plafond annoncé.
void main() {
  /// Un catalogue de [total] livres, servi page par page comme le fait le
  /// serveur. Chaque appel est enregistré : c'est lui qu'on vérifie.
  ({BookService service, List<Uri> appels}) serveurAvec(int total) {
    final appels = <Uri>[];

    final client = MockClient((requete) async {
      appels.add(requete.url);

      final limite = int.parse(requete.url.queryParameters['limit'] ?? '10');
      final page = int.parse(requete.url.queryParameters['page'] ?? '1');
      final debut = (page - 1) * limite;

      final livres = <Map<String, dynamic>>[];
      for (var i = debut; i < debut + limite && i < total; i++) {
        livres.add({'id': 'livre-$i', 'titre': 'Livre $i'});
      }

      return http.Response(jsonEncode({'data': livres}), 200);
    });

    return (service: BookService(client: client), appels: appels);
  }

  group('Un ensemble borné est chargé en entier', () {
    test('au-dela de la page par defaut, les pages sont enchainees', () async {
      // 150 livres, plafond par défaut de 200 : deux pages, la seconde
      // incomplète. Le serveur, lui, n'en rendrait que dix à un appel muet.
      final s = serveurAvec(150);

      final livres = await s.service.getAllBooks();

      expect(livres.length, 150, reason: 'la liste est tronquee en silence');
      expect(s.appels.length, 2);
    });

    /// Une page pleine est le seul indice qu'il reste des livres — la réponse
    /// ne porte pas de compteur total. Une page incomplète arrête la boucle,
    /// sinon on demanderait une page vide de plus à chaque ouverture d'écran.
    test('une page incomplete arrete la demande', () async {
      final s = serveurAvec(40);

      final livres = await s.service.getAllBooks();

      expect(livres.length, 40);
      expect(s.appels.length, 1, reason: 'une page vide a ete demandee en trop');
    });

    test('un catalogue vide ne declenche qu\'un appel', () async {
      final s = serveurAvec(0);

      expect(await s.service.getAllBooks(), isEmpty);
      expect(s.appels.length, 1);
    });

    test('chaque appel porte limit et page', () async {
      final s = serveurAvec(5);

      await s.service.getAllBooks();

      expect(s.appels.single.queryParameters['limit'], isNotNull);
      expect(s.appels.single.queryParameters['page'], '1');
    });
  });

  group('Le plafond est ferme', () {
    /// C'est tout l'objet : aucun écran ne doit pouvoir déclencher le
    /// téléchargement d'un catalogue entier, quelle que soit sa taille.
    test('le chargement s\'arrete au plafond annonce', () async {
      final s = serveurAvec(100000);

      final livres = await s.service.getAllBooks(maximum: 250);

      expect(livres.length, 250);
      expect(
        s.appels.length,
        3,
        reason: 'le chargement continue au-dela du plafond annonce',
      );
    });

    /// Trois pages pour 250 livres : 100, 100, puis 50 — et non 100, ce qui
    /// ferait transiter cinquante livres jetés aussitôt.
    test('la derniere requete ne demande que ce qui manque', () async {
      final s = serveurAvec(100000);

      await s.service.getAllBooks(maximum: 250);

      expect(s.appels.last.queryParameters['limit'], '50');
    });
  });

  group('Une page precise reste une page precise', () {
    /// Les écrans qui chargent la suite au défilement doivent obtenir ce
    /// qu'ils demandent, et rien d'autre.
    test('demander une page n\'en enchaine pas d\'autres', () async {
      final s = serveurAvec(500);

      final livres = await s.service.getBooksPage(limit: 20, page: 2);

      expect(livres.length, 20);
      expect(livres.first.id, 'livre-20');
      expect(s.appels.length, 1);
    });

    test('une page au-dela de la fin est vide, sans erreur', () async {
      final s = serveurAvec(10);

      expect(await s.service.getBooksPage(limit: 20, page: 5), isEmpty);
    });
  });

  group('Un serveur qui refuse ne passe pas pour un catalogue vide', () {
    /// Le limiteur de débit répond 429. Le service rendait une liste vide,
    /// exactement comme un catalogue réellement vide : à l'écran, « aucun
    /// livre » — et personne ne cherchait du côté du serveur.
    test('un refus rend une liste vide sans lever', () async {
      final service = BookService(
        client: MockClient(
          (_) async => http.Response('{"error":"Trop de requetes."}', 429),
        ),
      );

      expect(await service.getAllBooks(), isEmpty);
    });

    test('une panne reseau non plus', () async {
      final service = BookService(
        client: MockClient((_) async => throw const _PanneReseau()),
      );

      expect(await service.getAllBooks(), isEmpty);
    });
  });
}

class _PanneReseau implements Exception {
  const _PanneReseau();
}
