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
    ///
    /// CE GROUPE ATTENDAIT L'INVERSE DE SON PROPRE TITRE. Il vérifiait que le
    /// service « rend une liste vide sans lever » — c'est-à-dire précisément
    /// le défaut que son intitulé condamne, et que le commentaire ci-dessus
    /// décrit au passé. Un demi-correctif avait été verrouillé par un test :
    /// le service ne devinait plus de pages, mais il continuait de traduire
    /// une panne en catalogue vide. Le service lève désormais, et l'écran
    /// affiche l'erreur avec un bouton « Réessayer » ; le test dit maintenant
    /// ce que le groupe promet.
    test('un refus lève, avec le message du serveur', () async {
      final service = BookService(
        client: MockClient(
          (_) async => http.Response('{"error":"Trop de requetes."}', 429),
        ),
      );

      await expectLater(
        service.getAllBooks(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'le message du serveur',
            contains('Trop de requetes.'),
          ),
        ),
      );
    });

    test('une panne reseau lève aussi, au lieu de rendre une liste vide',
        () async {
      final service = BookService(
        client: MockClient((_) async => throw const _PanneReseau()),
      );

      await expectLater(service.getAllBooks(), throwsA(isA<Exception>()));
    });

    /// Un 404 déclenchait une RELANCE sans le filtre, dont le résultat était
    /// rendu à l'appelant comme si c'était sa liste filtrée. Le rapport de
    /// ventes demande `getAllBooks(auteurId: …)` pour retrouver les titres de
    /// SES livres : il recevait jusqu'à mille livres de toute la plateforme.
    /// Rendre les livres d'autrui à la place des siens est pire qu'une erreur.
    test('un 404 sur une liste filtrée ne rend pas le catalogue entier',
        () async {
      final appels = <Uri>[];
      final service = BookService(
        client: MockClient((requete) async {
          appels.add(requete.url);
          return http.Response('{"error":"Not Found"}', 404);
        }),
      );

      await expectLater(
        service.getAllBooks(auteurId: 'auteur-7'),
        throwsA(isA<Exception>()),
      );

      // Un seul appel, et il portait bien le filtre : pas de seconde requête
      // sans `auteur_id`.
      expect(appels, hasLength(1));
      expect(appels.single.queryParameters['auteur_id'], 'auteur-7');
    });
  });

  /// La boutique — le seul écran à défilement infini — n'appelle NI
  /// `getAllBooks` NI `getBooksPage` : elle appelle `getCataloguePage`, une
  /// méthode distincte, avec son propre curseur, son propre parsing de `meta`
  /// et son propre `throw`. Rien ne la couvrait, alors que c'est SA régression
  /// (page vide et `aUneSuite=false` sur panne) qui posait « fin du catalogue »
  /// après un hoquet réseau et affichait « Vous avez vu tous les livres ».
  group('La page de catalogue rend ce que le serveur a dit', () {
    test('un refus lève, il ne rend pas une page vide', () async {
      final service = BookService(
        client: MockClient(
          (_) async => http.Response(
            '{"error":"Le catalogue est momentanement indisponible."}',
            500,
          ),
        ),
      );

      await expectLater(
        service.getCataloguePage(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'le message du serveur',
            contains('momentanement indisponible'),
          ),
        ),
      );
    });

    test('une panne reseau lève aussi', () async {
      final service = BookService(
        client: MockClient((_) async => throw const _PanneReseau()),
      );

      await expectLater(service.getCataloguePage(), throwsA(isA<Exception>()));
    });

    test('le curseur et la suite annonces sont relus tels quels', () async {
      final service = BookService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {'id': 'livre-0', 'titre': 'Livre 0'},
              ],
              'meta': {
                'a_une_suite': true,
                'curseur_suivant': 'eyJjIjoiMjAyNi0wOS0wNiJ9',
                'total': 4213,
              },
            }),
            200,
          ),
        ),
      );

      final page = await service.getCataloguePage();

      expect(page.livres.single.id, 'livre-0');
      expect(page.aUneSuite, isTrue);
      expect(page.curseurSuivant, 'eyJjIjoiMjAyNi0wOS0wNiJ9');
      // Le total exact, calculé par le serveur sur la première page : sans
      // lui, la boutique affichait le nombre de livres déjà téléchargés à la
      // place de la taille du catalogue.
      expect(page.total, 4213);
    });

    /// Le serveur n'envoie `total` qu'avec la première page. Absent, il vaut
    /// `null` — surtout pas zéro, qui se lirait « catalogue vide ».
    test('une fin de catalogue n\'invente ni suite ni total', () async {
      final service = BookService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': <Map<String, dynamic>>[],
              'meta': {'a_une_suite': false},
            }),
            200,
          ),
        ),
      );

      final page = await service.getCataloguePage(apres: 'curseur-quelconque');

      expect(page.livres, isEmpty);
      expect(page.aUneSuite, isFalse);
      expect(page.curseurSuivant, isNull);
      expect(page.total, isNull);
    });

    test('le curseur repart au serveur tel qu\'il en est venu', () async {
      final appels = <Uri>[];
      final service = BookService(
        client: MockClient((requete) async {
          appels.add(requete.url);
          return http.Response(
            jsonEncode({'data': [], 'meta': {'a_une_suite': false}}),
            200,
          );
        }),
      );

      // Un curseur opaque : le client ne l'interprète pas, il le rend.
      const curseur = 'MjAyNi0wOS0wNlQxMjozNDo1Nnw3ZjNi';
      await service.getCataloguePage(apres: curseur, recherche: 'quantique');

      expect(appels.single.queryParameters['apres'], curseur);
      // La recherche voyage sous `q`, comme sur l'autre chemin.
      expect(appels.single.queryParameters['q'], 'quantique');
    });
  });
}

class _PanneReseau implements Exception {
  const _PanneReseau();
}
