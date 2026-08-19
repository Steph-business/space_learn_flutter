import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:space_learn_flutter/core/space_learn/data/dataServices/authorStatsService.dart';
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

/// Les chiffres de l'auteur, et ce qu'ils disent quand ils manquent.
///
/// Le service rendait un objet vide sur un appel refusé. Le tableau de bord
/// l'affichait comme n'importe quel autre résultat : 0 vente, 0 F CFA. Rien ne
/// distinguait un mois sans lecteur d'un serveur qui avait dit non — et un
/// chiffre d'affaires faux est pire qu'un chiffre absent, parce qu'on le croit.
void main() {
  AuthorStatsService serviceQuiRepond(http.Response reponse) =>
      AuthorStatsService(client: MockClient((_) async => reponse));

  group('Quand le serveur répond', () {
    test('les chiffres sont rendus tels quels', () async {
      final service = serviceQuiRepond(
        http.Response('{"data":{"ventes":12,"revenus":45000}}', 200),
      );

      final stats = await service.getAuthorStats(
        'auteur-1',
        '',
        authToken: 'jeton',
      );

      expect(stats['ventes'], 12);
      expect(stats['revenus'], 45000);
    });

    /// Un auteur qui n'a rien vendu ce mois-ci : c'est un résultat, pas un
    /// échec. Lui, on le rend vide — et sans lever.
    test('une absence de vente reste une absence de vente', () async {
      final service = serviceQuiRepond(http.Response('{"data":{}}', 200));

      final stats = await service.getAuthorRevenue(
        'auteur-1',
        'mois',
        authToken: 'jeton',
      );

      expect(stats, isEmpty);
    });
  });

  group('Quand le serveur refuse', () {
    test('un échec lève au lieu de se faire passer pour zéro', () async {
      final service = serviceQuiRepond(http.Response('{}', 500));

      expect(
        () => service.getAuthorStats('auteur-1', '', authToken: 'jeton'),
        throwsA(isA<Exception>()),
      );
    });

    test('le message est présentable', () async {
      final service = serviceQuiRepond(http.Response('{}', 500));

      try {
        await service.getAuthorRevenue('auteur-1', '', authToken: 'jeton');
        fail('un 500 doit lever');
      } catch (e) {
        final phrase = messageLisible(e);
        expect(phrase, isNot(contains('{')));
        expect(phrase, isNot(contains('Exception')));
        expect(phrase, contains('indisponible'));
      }
    });

    /// Le 401 ne se raconte pas avec le mot du serveur : « token » ne veut
    /// rien dire pour la personne qui lit, et le geste utile n'est pas de
    /// réessayer.
    test('une session finie se dit en français', () async {
      final service = serviceQuiRepond(
        http.Response('{"error":"Token invalide ou expiré"}', 401),
      );

      try {
        await service.getAuthorStats('auteur-1', '', authToken: 'jeton');
        fail('un 401 doit lever');
      } catch (e) {
        expect(messageLisible(e), contains('session a expiré'));
      }
    });
  });
}
