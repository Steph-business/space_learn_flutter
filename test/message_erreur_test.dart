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
    /// L'en-tête de charset n'est pas décoratif : sans lui, `http.Response`
    /// encode le corps en Latin-1 et le tiret cadratin des phrases du serveur
    /// fait tomber la construction. Les serveurs, eux, répondent en UTF-8.
    http.Response reponse(int code, [Object? corps]) => http.Response(
      corps == null ? '' : jsonEncode(corps),
      code,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

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

    /// LES PHRASES RÉELLES DES DEUX SERVEURS, REJOUÉES TELLES QUELLES.
    ///
    /// Un plafond de deux cents caractères vivait dans `_estPresentable`. Il
    /// jetait ces phrases-là — le mobile affichait alors « Cette opération
    /// entre en conflit avec un enregistrement existant. » ou « Vous n'avez pas
    /// accès à cette ressource. », pendant que le site, qui n'a aucun plafond,
    /// affichait la cause, la date et l'adresse où écrire.
    ///
    /// Elles sont recopiées ici mot pour mot depuis le code des serveurs. Si
    /// l'une d'elles cesse de passer, ce test rougit AVANT que quelqu'un ne
    /// découvre l'écran muet.
    test('les phrases longues des serveurs arrivent à l\'écran', () {
      // space_learn_auth, controllers/register.go — 409 de réinscription.
      const reinscription =
          "Un compte existe déjà avec cette adresse. Connectez-vous, par mot de "
          "passe ou avec Google : un code vous sera renvoyé si le compte n'est "
          "pas validé, et la connexion annule une suppression récente.";
      // space_learn_auth, controllers/login.go — 403 de compte fermé, daté.
      const compteFerme =
          "Ce compte a été fermé le 12/03/2026 et ne peut plus être rouvert "
          "ici : le délai pour annuler est écoulé, ou l'administration l'a "
          "exclu. Écrivez à contact@spacelearn.com.";
      // space_learn_auth, controllers/login.go — 403 de compte non vérifié
      // quand la cadence vient de retenir un envoi.
      const codeDejaParti =
          "Votre email n'est pas encore vérifié. Un code vous a déjà été "
          "adressé il y a moins d'une minute : utilisez celui-là.";
      // space_learn_auth, controllers/user.go — la réponse de DeleteAccount,
      // la plus longue des trois serveurs (329 caractères).
      const suppression =
          "Votre compte a été fermé et vos appareils déconnectés. Votre nom "
          "n'est plus affiché. Vos données personnelles seront effacées le "
          "06/10/2026 ; d'ici là, reconnectez-vous — par mot de passe ou avec "
          "Google — pour annuler la suppression. Votre adresse e-mail reste "
          "réservée jusqu'à cette date : elle ne peut pas servir à un nouveau "
          "compte avant.";
      // space_learn_livres, modules/reversement/controller.go — 409 de carence.
      const carence =
          "Le numéro qui reçoit vos virements a été changé récemment. Par "
          "sécurité, aucun retrait n'est possible avant le 07/09/2026 à 14h30. "
          "Si ce changement ne vient pas de vous, rétablissez votre numéro et "
          "changez votre mot de passe sans attendre.";

      final cas = <int, String>{
        409: reinscription,
        403: compteFerme,
        422: codeDejaParti,
        400: suppression,
        402: carence,
      };

      cas.forEach((code, phrase) {
        expect(
          messageDeLaReponse(reponse(code, {'error': phrase})),
          phrase,
          reason: 'phrase de $code jetée : ${phrase.length} caractères',
        );
      });

      // Le serveur des livres porte ses messages sous `message`, pas `error`.
      expect(messageDeLaReponse(reponse(409, {'message': carence})), carence);
    });

    /// Ce que le plafond protégeait vraiment, distingué par ce qu'il EST.
    test('un déversement reste écarté, quelle que soit sa longueur', () {
      final rebuts = <String>[
        // Une trace de pile : un cadre par ligne.
        'Erreur\n  à la ligne 12\n  à la ligne 34\n  à la ligne 56',
        // Un jeton, une empreinte, une adresse encodée : un « mot » qui n'en
        // est pas un.
        'Jeton refusé eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefghijklmnop',
        // Un texte qui n'a pas été écrit pour une boîte de dialogue.
        'Le service a rencontré une difficulté. ' * 30,
      ];
      for (final rebut in rebuts) {
        expect(
          messageDeLaReponse(reponse(500, {'error': rebut})),
          "Le service est momentanément indisponible. Réessayez dans un instant.",
          reason: 'aurait laissé passer : $rebut',
        );
      }
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

    /// LA FORME QUE LES ÉCRANS REÇOIVENT VRAIMENT, et qui n'était pas reconnue.
    ///
    /// Sur un 401, `messageDeLaReponse` ne relaie plus le mot du serveur : il
    /// rend `phraseSessionExpiree`, que le service enveloppe dans une
    /// `Exception`. Les tests ci-dessus ne couvraient que des formes brutes du
    /// serveur que plus aucun écran ne voit passer ; celle-ci, la seule qui
    /// arrive réellement, rendait `false` — et les quatorze écrans qui règlent
    /// leur bouton dessus offraient « Réessayer » sur un jeton mort.
    test('la phrase que l\'application produit elle-même est reconnue', () {
      final reponse401 = http.Response('{"error":"Token invalide"}', 401);
      final phrase = messageDeLaReponse(reponse401);

      expect(phrase, phraseSessionExpiree);
      expect(estSessionExpiree(Exception(phrase)), isTrue);
      expect(estSessionExpiree(phrase), isTrue);
    });

    test('les variantes écrites à la main dans les écrans sont reconnues', () {
      final cas = [
        Exception('Votre session a expiré. Reconnectez-vous, puis réessayez.'),
        Exception('Votre session a expiré. Reconnectez-vous pour publier.'),
        Exception('Session expirée. Veuillez vous reconnecter.'),
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
