import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:space_learn_flutter/core/utils/message_erreur.dart';

void main() {
  group('Le message vu à l\'écran', () {
    /// Le cas exact de la capture d'écran, bout en bout.
    ///
    /// Trois couches avaient chacune ajouté leur part : le serveur son JSON, le
    /// service son `Exception(...)`, l'écran son `$e`.
    test('la capture d\'écran ne peut plus se reproduire', () {
      final erreur = Exception(
        'Erreur de récupération du profil : {"error":"Token invalide ou expiré"}',
      );

      final message = messageLisible(erreur);

      expect(message, isNot(contains('Exception')));
      expect(message, isNot(contains('{')));
      expect(message, isNot(contains('"error"')));
      expect(message.toLowerCase(), contains('session'));
    });

    test('le préfixe Exception est retiré', () {
      expect(
        messageLisible(Exception('Ce livre est introuvable')),
        'Ce livre est introuvable.',
      );
    });

    test('une panne réseau se dit en français', () {
      final message = messageLisible(
        http.ClientException('Failed host lookup: api.example.com'),
      );
      expect(message.toLowerCase(), contains('connexion'));
      expect(message, isNot(contains('host')));
    });

    test('un dépassement de délai se distingue d\'une panne', () {
      final message = messageLisible(TimeoutException('délai'));
      expect(message.toLowerCase(), contains('temps'));
    });

    /// La règle de prudence : dans le doute, taire.
    test('une trace technique est remplacée, jamais affichée', () {
      final techniques = [
        Exception('Instance of \'_ReponseInterne\''),
        Exception('#0 main (package:space_learn/main.dart:12)'),
        Exception('SQLSTATE 23505 duplicate key'),
        Exception('null'),
        Exception('{"code":500}'),
        StateError('Bad state: no element'),
      ];

      for (final e in techniques) {
        final message = messageLisible(e);
        expect(
          message,
          "Une erreur est survenue. Réessayez dans un instant.",
          reason: 'aurait laissé passer : $e',
        );
      }
    });

    /// Quarante messages de développeur restent en anglais dans la couche
    /// service. Rien en eux ne sent la trace technique : sans ce filtre, ils
    /// s'afficheraient tels quels à quelqu'un qui lit en français.
    test('un message de développeur anglais ne parvient pas à l\'écran', () {
      final anglais = [
        Exception('Failed to fetch followers'),
        Exception('Failed to toggle like'),
        Exception('Unable to load data'),
      ];
      for (final e in anglais) {
        expect(
          messageLisible(e, repli: 'Action impossible.'),
          'Action impossible.',
          reason: 'aurait laissé passer : $e',
        );
      }
    });

    test('nul donne le repli, pas le mot « null »', () {
      expect(messageLisible(null), isNot(contains('null')));
    });

    test('la phrase se termine par un point et commence par une majuscule', () {
      expect(
        messageLisible(Exception('livre introuvable')),
        'Livre introuvable.',
      );
    });
  });

  group('Le message tiré d\'une réponse HTTP', () {
    http.Response reponse(int code, [Object? corps]) =>
        http.Response(corps == null ? '' : jsonEncode(corps), code);

    /// Le serveur écrit des phrases utilisables : les jeter pour un message
    /// générique prive l'auteur de la cause et du remède.
    test('la phrase du serveur l\'emporte sur le code', () {
      final message = messageDeLaReponse(
        reponse(422, {
          'error':
              'ce manuscrit est trop court pour être publié : 4 page(s) déposée(s), 10 au minimum',
        }),
      );
      expect(message, contains('trop court'));
      expect(message, contains('10 au minimum'));
    });

    test('un 401 annonce la session, pas un code', () {
      final message = messageDeLaReponse(reponse(401));
      expect(message.toLowerCase(), contains('session'));
      expect(message, isNot(contains('401')));
    });

    test('un 500 invite à réessayer', () {
      expect(
        messageDeLaReponse(reponse(503)).toLowerCase(),
        contains('indisponible'),
      );
      expect(
        messageDeLaReponse(reponse(500)).toLowerCase(),
        contains('indisponible'),
      );
    });

    /// Une passerelle qui répond du HTML ne doit pas se retrouver à l'écran.
    test('un corps non-JSON est ignoré', () {
      final message = messageDeLaReponse(
        http.Response('<html><body>502 Bad Gateway</body></html>', 502),
      );
      expect(message, isNot(contains('<')));
      expect(message.toLowerCase(), contains('indisponible'));
    });

    test('un corps JSON technique est ignoré', () {
      final message = messageDeLaReponse(
        reponse(500, {'error': 'pq: relation "livres" does not exist'}),
      );
      expect(message, isNot(contains('pq:')));
    });
  });

  group('Reconnaître une session expirée', () {
    /// Un jeton mort ne se répare pas en réessayant : proposer « Réessayer »
    /// offre un bouton qui ne peut par construction jamais aboutir.
    test('les formes renvoyées par le serveur sont reconnues', () {
      final cas = [
        Exception('{"error":"Token invalide ou expiré"}'),
        Exception('Session expirée, reconnectez-vous.'),
        Exception('Utilisateur non authentifié'),
        Exception('unauthorized'),
      ];
      for (final e in cas) {
        expect(estSessionExpiree(e), isTrue, reason: '$e');
      }
    });

    test('une panne réseau n\'est pas une session expirée', () {
      expect(
        estSessionExpiree(http.ClientException('Failed host lookup')),
        isFalse,
      );
      expect(estSessionExpiree(Exception('Livre introuvable')), isFalse);
      expect(estSessionExpiree(null), isFalse);
    });
  });
}
